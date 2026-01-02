// ==UserScript==
// @name         提取tweetText内容到剪贴板（去除省略号+增强data-text节点）
// @namespace    http://tampermonkey.net/
// @version      0.3
// @description  在x.com通过data-testid="tweetText"获取第一个元素的文本，同时提取所有data-text="true"节点文本，去除省略号后复制到剪贴板
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

    // 【新增】文本清理工具函数（统一处理所有文本，避免冗余）
    const cleanText = (text) => {
        if (!text) return '';
        return text
            .trim() // 去除首尾空白
            .replace(/…/g, '') // 全局替换所有省略号
            .replace(/\n{3,}/g, '\n\n'); // 清理多余空行，最多保留2个连续换行
    };

    // 点击事件：增强文本获取逻辑（保留原有功能，新增data-text节点提取）
    button.addEventListener('click', () => {
        // 1. 保留原有：获取[data-testid="tweetText"]第一个元素文本
        const tweetTextElement = document.querySelector('[data-testid="tweetText"]');
        const tweetText = tweetTextElement ? cleanText(tweetTextElement.textContent) : '';

        // 2. 【新增】获取所有[data-text="true"]节点文本，批量提取并整理
        const dataTextNodes = document.querySelectorAll('[data-text="true"]');
        let dataTextContent = '';
        if (dataTextNodes.length > 0) {
            // 遍历所有目标节点，逐个清理并拼接（节点间用双换行分隔，保持格式清晰）
            dataTextNodes.forEach(node => {
                const nodeText = cleanText(node.textContent);
                if (nodeText) {
                    dataTextContent += `${nodeText}\n\n`;
                }
            });
            // 对拼接后的data-text内容做最终清理，去除尾部多余空行
            dataTextContent = cleanText(dataTextContent);
        }

        // 3. 【新增】合并两部分文本（优先保留tweetText，再拼接data-text，避免内容混乱）
        let finalText = '';
        if (tweetText && dataTextContent) {
            // 两者都存在时，用分隔线区分（可选，可删除分隔线仅保留换行）
            finalText = `${tweetText}\n\n---\n\n${dataTextContent}`;
        } else if (tweetText) {
            finalText = tweetText;
        } else if (dataTextContent) {
            finalText = dataTextContent;
        }

        // 4. 验证并复制文本（保留原有提示逻辑，优化判断条件）
        if (finalText) {
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
            // 两者都未找到时，给出更精准的提示
            alert('未找到包含 data-testid="tweetText" 或 data-text="true" 的有效元素');
        }
    });

    document.body.appendChild(button);
})();
