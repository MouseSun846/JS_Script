// ==UserScript==
// @name         提取tweetText内容到剪贴板（去除省略号）
// @namespace    http://tampermonkey.net/
// @version      0.2
// @description  在x.com通过data-testid="tweetText"获取第一个元素的文本，去除省略号后复制到剪贴板
// @author       豆包编程助手
// @match        *://*.x.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // 创建浮动按钮
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

    // 按钮悬停效果
    button.addEventListener('mouseover', () => {
        button.style.backgroundColor = '#1a91da';
    });
    button.addEventListener('mouseout', () => {
        button.style.backgroundColor = '#1DA1F2';
    });

    // 点击事件：获取文本并处理
    button.addEventListener('click', () => {
        const targetElement = document.querySelector('[data-testid="tweetText"]');
        
        if (targetElement) {
            // 1. 获取原始文本并去除首尾空白
            let textContent = targetElement.textContent.trim();
            
            // 2. 去除所有省略号（…）
            textContent = textContent.replace(/…/g, ''); // 全局替换所有省略号
            
            // 3. 清理多余空行（最多保留2个连续换行）
            textContent = textContent.replace(/\n{3,}/g, '\n\n');
            
            // 复制到剪贴板
            navigator.clipboard.writeText(textContent)
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
            alert('未找到包含 data-testid="tweetText" 的元素');
        }
    });

    document.body.appendChild(button);
})();
