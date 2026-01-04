/**
 * @fileoverview 랜딩 페이지 JavaScript
 * @description 스크롤 애니메이션 및 구글 시트 연결 기능
 */

/**
 * 구글 시트 URL (조건 입력 폼)
 * @const {string}
 */
const GOOGLE_SHEET_URL = 'YOUR_GOOGLE_SHEET_URL_HERE'; // TODO: 실제 구글 시트 URL로 변경

/**
 * 페이지 로드 완료 시 초기화
 */
document.addEventListener('DOMContentLoaded', function() {
    initScrollAnimations();
    initHeaderScroll();
    Logger.log('랜딩 페이지 로드 완료');
});

/**
 * 스크롤 애니메이션 초기화
 */
function initScrollAnimations() {
    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // 모든 fade-in 요소 관찰
    const fadeElements = document.querySelectorAll('.fade-in');
    fadeElements.forEach(el => {
        observer.observe(el);
    });
}

/**
 * 헤더 스크롤 효과
 */
function initHeaderScroll() {
    const header = document.querySelector('.header');
    let lastScroll = 0;

    window.addEventListener('scroll', function() {
        const currentScroll = window.pageYOffset;

        if (currentScroll > 100) {
            header.style.boxShadow = '0 4px 6px -1px rgba(0, 0, 0, 0.1)';
        } else {
            header.style.boxShadow = '0 1px 2px 0 rgba(0, 0, 0, 0.05)';
        }

        lastScroll = currentScroll;
    });
}

/**
 * 섹션으로 부드럽게 스크롤
 * @param {string} sectionId - 섹션 ID
 */
function scrollToSection(sectionId) {
    const section = document.getElementById(sectionId);
    if (section) {
        const headerHeight = document.querySelector('.header').offsetHeight;
        const sectionTop = section.offsetTop - headerHeight;
        
        window.scrollTo({
            top: sectionTop,
            behavior: 'smooth'
        });
    }
}

/**
 * 구글 시트 조건 입력 폼으로 이동
 */
function goToConditionForm() {
    if (GOOGLE_SHEET_URL && GOOGLE_SHEET_URL !== 'YOUR_GOOGLE_SHEET_URL_HERE') {
        // 새 창에서 구글 시트 열기
        window.open(GOOGLE_SHEET_URL, '_blank');
        
        // 또는 현재 창에서 열기
        // window.location.href = GOOGLE_SHEET_URL;
    } else {
        // 구글 시트 URL이 설정되지 않은 경우
        Logger.warn('구글 시트 URL이 설정되지 않았습니다.');
        alert('조건 입력 폼이 준비 중입니다. 곧 이용하실 수 있습니다.');
        
        // 임시로 기존 검색 페이지로 이동
        // window.location.href = 'index.html';
    }
}

/**
 * 통계 숫자 카운트 애니메이션
 */
function animateStats() {
    const statNumbers = document.querySelectorAll('.stat-number');
    
    statNumbers.forEach(stat => {
        const target = stat.textContent;
        const isNumber = !isNaN(parseInt(target));
        
        if (isNumber && target !== '0') {
            const finalValue = parseInt(target);
            let currentValue = 0;
            const increment = finalValue / 50;
            const duration = 2000; // 2초
            const stepTime = duration / 50;
            
            const timer = setInterval(() => {
                currentValue += increment;
                if (currentValue >= finalValue) {
                    stat.textContent = finalValue;
                    clearInterval(timer);
                } else {
                    stat.textContent = Math.floor(currentValue);
                }
            }, stepTime);
        }
    });
}

/**
 * 통계 섹션이 보일 때 애니메이션 시작
 */
const statsObserver = new IntersectionObserver(function(entries) {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            animateStats();
            statsObserver.unobserve(entry.target);
        }
    });
}, { threshold: 0.5 });

const heroStats = document.querySelector('.hero-stats');
if (heroStats) {
    statsObserver.observe(heroStats);
}

/**
 * 모바일 메뉴 토글 (필요시 추가)
 */
function toggleMobileMenu() {
    const nav = document.querySelector('.nav');
    nav.classList.toggle('mobile-open');
}

/**
 * 부드러운 스크롤을 위한 헬퍼 함수
 * @param {Element} element - 스크롤할 요소
 */
function smoothScrollTo(element) {
    if (element) {
        element.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }
}


