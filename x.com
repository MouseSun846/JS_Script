// ==UserScript==
// @name         提取推文内容+图片（紧凑排版+无重复+保留顺序）
// @namespace    http://tampermonkey.net/
// @version      0.7
// @description  在x.com按页面原始顺序提取内容，有序去重并去除连续换行，Markdown格式紧凑复制到剪贴板
// @author       豆包编程助手
// @match        *://*.x.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // 创建浮动按钮（保留原有样式，无改动）
    const button = document.createElement('button');
    button.textContent = '复制推文内容';
    button.style.position = 'fixed';
    button.style.top = '20px';
    button.style.right = '20px';
    button.style.zIndex = '9999';
    button.style.padding = '10px 15px';
    button.style.backgroundColor = '#1DA1F2'; // x.com主题色
    button.style.color = 'white';
    button.style.border = 'none';
    button.style.borderRadius = '5px';
    button.style.cursor = 'pointer';
    button.style.boxShadow = '0 2px 8px rgba(0,0,0,0.2)';
    button.style.transition = 'background-color 0.2s';

    // 按钮悬停效果（保留原有逻辑，无改动）
    button.addEventListener('mouseover', () => {
        button.style.backgroundColor = '#1a91da';
    });
    button.addEventListener('mouseout', () => {
        button.style.backgroundColor = '#1DA1F2';
    });

    // 【核心修改】文本清理工具函数：去除所有连续换行（保留单个换行）
    const cleanText = (text) => {
        if (!text) return '';
        return text
            .trim() // 去除首尾空白
            .replace(/…/g, '') // 全局替换所有省略号
            .replace(/\s{2,}/g, ' ') // 清理多余连续空格
            .replace(/\n{2,}/g, '\n'); // 【关键修改】将2个及以上连续换行，替换为单个换行（彻底去除双换行）
    };

    // 图片转换工具函数（保留原有过滤逻辑，无改动）
    const convertImgToMarkdown = (imgNode, srcSet) => {
        const imgSrc = imgNode.src.trim();
        // 过滤无效地址：空值、base64小图标、svg图标、短地址图标
        if (
            imgSrc &&
            !imgSrc.startsWith('data:image/svg+xml') &&
            !imgSrc.startsWith('data:image/png;base64') &&
            imgSrc.length > 20 && // 过滤短地址图标
            !srcSet.has(imgSrc)
        ) {
            srcSet.add(imgSrc); // 图片src去重，避免生成重复图片Markdown
            return `![推文图片](${imgSrc})`; // Markdown图片语法
        }
        return '';
    };

    // 按原始顺序遍历提取+有序去重（无改动，仅适配换行清理）
    const extractContentInOrder = () => {
        // 1. 定位推文核心容器（优先以tweetText为核心，确保提取范围准确）
        const tweetContainer = document.querySelector('[data-testid="tweetText"]')
            || document.body; // 兜底：若未找到tweetText，遍历整个页面body

        // 2. 定义关键集合和数组
        const srcSet = new Set(); // 图片src去重（前置过滤）
        const contentSet = new Set(); // 存储已提取的有效内容，用于有序去重
        const extractedContent = []; // 按顺序存储去重后的最终内容
        const processedNodes = new Set(); // 避免重复处理同一DOM节点

        // 3. 递归遍历DOM节点，按页面渲染顺序提取+去重
        const traverseDOM = (node) => {
            // 跳过已处理节点、隐藏节点、注释节点
            if (
                processedNodes.has(node) ||
                node.nodeType === Node.COMMENT_NODE ||
                (node.nodeType === Node.ELEMENT_NODE &&
                    (window.getComputedStyle(node).display === 'none' ||
                     window.getComputedStyle(node).visibility === 'hidden'))
            ) {
                return;
            }

            processedNodes.add(node); // 标记为已处理

            // 情况1：元素节点 - 处理目标文本节点和图片节点
            if (node.nodeType === Node.ELEMENT_NODE) {
                let currentContent = '';

                // ① 处理[data-testid="tweetText"]节点（文本）
                if (node.hasAttribute('data-testid') && node.getAttribute('data-testid') === 'tweetText') {
                    currentContent = cleanText(node.textContent);
                }

                // ② 处理[data-text="true"]节点（文本）
                else if (node.hasAttribute('data-text') && node.getAttribute('data-text') === 'true') {
                    currentContent = cleanText(node.textContent);
                }

                // ③ 处理img节点（转换为Markdown图片）
                else if (node.tagName === 'IMG') {
                    currentContent = convertImgToMarkdown(node, srcSet);
                }

                // 有序去重逻辑：仅保留首次出现的内容
                if (currentContent && !contentSet.has(currentContent)) {
                    contentSet.add(currentContent); // 记录已出现的内容
                    extractedContent.push(currentContent); // 加入最终数组，保留原始顺序
                }

                // 递归遍历子节点（保持DOM树的原始顺序）
                for (let i = 0; i < node.childNodes.length; i++) {
                    traverseDOM(node.childNodes[i]);
                }
            }

            // 情况2：文本节点 - 跳过无意义空白文本，有序去重
            else if (node.nodeType === Node.TEXT_NODE) {
                const currentContent = cleanText(node.textContent);
                // 仅当文本有效、未出现过、长度大于5时保留（避免无关小字）
                if (currentContent && currentContent.length > 5 && !contentSet.has(currentContent)) {
                    contentSet.add(currentContent);
                    extractedContent.push(currentContent);
                }
            }
        };

        // 启动DOM遍历，按原始顺序提取+去重
        traverseDOM(tweetContainer);

        // 4. 【关键修改】拼接内容时使用单个换行（彻底杜绝双换行）
        return extractedContent.join('\n');
    };

    // 点击事件：紧凑排版内容复制（保留原有交互，无改动）
    button.addEventListener('click', () => {
        try {
            // 1. 按原始顺序提取+去重+紧凑排版所有内容
            const finalText = extractContentInOrder();

            // 2. 验证并复制文本
            if (finalText && finalText.length > 10) {
                navigator.clipboard.writeText(finalText)
                    .then(() => {
                        const originalText = button.textContent;
                        button.textContent = '✓ 已复制';
                        setTimeout(() => {
                            button.textContent = originalText;
                        }, 1500);
                    })
                    .catch(err => {
                        console.error('复制失败: ', err);
                        alert('复制失败，请手动复制内容');
                    });
            } else {
                alert('未找到有效的推文文本或图片（紧凑排版+去重后）');
            }
        } catch (err) {
            console.error('提取失败: ', err);
            alert('提取内容出错，请刷新页面重试');
        }
    });

    document.body.appendChild(button);
})();
