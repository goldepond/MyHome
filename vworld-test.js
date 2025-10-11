const puppeteer = require('puppeteer');

async function testVWorld() {
    const browser = await puppeteer.launch({
        headless: false, // 브라우저 창을 보여줌
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    try {
        console.log('🔍 V-WORLD 사이트 접속 중...');
        await page.goto('https://www.vworld.kr/dtld/broker/dtld_list_s001.do', { 
            waitUntil: 'networkidle2',
            timeout: 30000 
        });

        // 페이지 로딩 대기
        await new Promise(resolve => setTimeout(resolve, 5000));

        console.log('📄 페이지 제목:', await page.title());
        
        // 페이지의 모든 select 요소 찾기
        const selectElements = await page.evaluate(() => {
            const selects = document.querySelectorAll('select');
            return Array.from(selects).map(select => ({
                name: select.name,
                id: select.id,
                className: select.className,
                options: Array.from(select.options).map(option => ({
                    value: option.value,
                    text: option.textContent
                }))
            }));
        });
        
        console.log('📋 발견된 select 요소들:', JSON.stringify(selectElements, null, 2));
        
        // 페이지의 HTML 구조 일부 확인
        const pageContent = await page.evaluate(() => {
            return document.body.innerHTML.substring(0, 2000);
        });
        
        console.log('📄 페이지 내용 (처음 2000자):', pageContent);
        
    } catch (error) {
        console.error('❌ 오류 발생:', error);
    } finally {
        await browser.close();
    }
}

testVWorld().catch(console.error);
