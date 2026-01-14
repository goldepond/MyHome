/**
 * @fileoverview 랜딩 페이지 JavaScript
 * @description 스크롤 애니메이션 및 조건 입력 폼 연결 기능
 */

/**
 * 조건 입력 폼 URL
 * @const {string}
 */
const GOOGLE_SHEET_URL = 'https://form.typeform.com/to/kwFQjb2w';

/**
 * 페이지 로드 완료 시 초기화
 */
document.addEventListener('DOMContentLoaded', function() {
    // 초기 콘텐츠 즉시 표시 (모바일 이탈률 개선)
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';
    
    // 모바일 메뉴 초기화
    initMobileMenu();
    
    // 데스크톱에서만 스크롤 애니메이션 적용
    if (window.innerWidth > 768) {
        initScrollAnimations();
    }
    
    initHeaderScroll();
    Logger.log('랜딩 페이지 로드 완료');
});

/**
 * 모바일 메뉴 초기화
 */
function initMobileMenu() {
    const mobileMenuToggle = document.getElementById('mobileMenuToggle');
    const nav = document.getElementById('mainNav');
    
    if (!mobileMenuToggle || !nav) {
        return;
    }
    
    try {
        mobileMenuToggle.addEventListener('click', function() {
            const isOpen = nav.classList.contains('mobile-open');
            nav.classList.toggle('mobile-open');
            mobileMenuToggle.classList.toggle('active');
            mobileMenuToggle.setAttribute('aria-expanded', !isOpen);
            mobileMenuToggle.setAttribute('aria-label', isOpen ? '메뉴 열기' : '메뉴 닫기');
        });
        
        // 키보드 접근성 개선
        mobileMenuToggle.addEventListener('keydown', function(event) {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                mobileMenuToggle.click();
            }
        });
        
        // 메뉴 외부 클릭 시 닫기
        document.addEventListener('click', function(event) {
            if (!nav.contains(event.target) && nav.classList.contains('mobile-open')) {
                nav.classList.remove('mobile-open');
                mobileMenuToggle.classList.remove('active');
                mobileMenuToggle.setAttribute('aria-expanded', 'false');
                mobileMenuToggle.setAttribute('aria-label', '메뉴 열기');
            }
        });
        
        // ESC 키로 메뉴 닫기
        document.addEventListener('keydown', function(event) {
            if (event.key === 'Escape' && nav.classList.contains('mobile-open')) {
                nav.classList.remove('mobile-open');
                mobileMenuToggle.classList.remove('active');
                mobileMenuToggle.setAttribute('aria-expanded', 'false');
                mobileMenuToggle.setAttribute('aria-label', '메뉴 열기');
                mobileMenuToggle.focus();
            }
        });
    } catch (error) {
        Logger.error('모바일 메뉴 초기화 실패:', error);
    }
}

/**
 * 스크롤 애니메이션 초기화 (데스크톱 전용)
 */
function initScrollAnimations() {
    // 모바일에서는 애니메이션 비활성화 (성능 및 이탈률 개선)
    if (window.innerWidth <= 768) {
        return;
    }
    
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
    try {
        const section = document.getElementById(sectionId);
        if (!section) {
            Logger.warn('섹션을 찾을 수 없습니다:', sectionId);
            return;
        }
        
        const header = document.querySelector('.header');
        const headerHeight = header ? header.offsetHeight : 0;
        const sectionTop = section.offsetTop - headerHeight;
        
        // 모바일 메뉴가 열려있으면 닫기
        const nav = document.getElementById('mainNav');
        const mobileMenuToggle = document.getElementById('mobileMenuToggle');
        if (nav && nav.classList.contains('mobile-open')) {
            nav.classList.remove('mobile-open');
            if (mobileMenuToggle) {
                mobileMenuToggle.classList.remove('active');
                mobileMenuToggle.setAttribute('aria-expanded', 'false');
                mobileMenuToggle.setAttribute('aria-label', '메뉴 열기');
            }
        }
        
        // 부드러운 스크롤
        window.scrollTo({
            top: sectionTop,
            behavior: 'smooth'
        });
        
        // 포커스 이동 (접근성)
        section.setAttribute('tabindex', '-1');
        section.focus();
    } catch (error) {
        Logger.error('스크롤 실패:', error);
    }
}

/**
 * 조건 입력 폼으로 이동
 */
function goToConditionForm() {
    try {
        if (!GOOGLE_SHEET_URL) {
            Logger.warn('조건 입력 폼 URL이 설정되지 않았습니다.');
            showUserMessage('조건 입력 폼이 준비 중입니다. 곧 이용하실 수 있습니다.', 'info');
            return;
        }
        
        // 모바일 감지
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        
        // 모바일에서는 같은 창에서 이동 (팝업 차단 방지)
        if (isMobile) {
            // 로딩 상태 표시 (선택사항)
            showLoadingState();
            window.location.href = GOOGLE_SHEET_URL;
        } else {
            // 데스크톱에서는 새 창에서 열기
            const newWindow = window.open(GOOGLE_SHEET_URL, '_blank', 'noopener,noreferrer');
            
            // 팝업 차단 확인
            if (!newWindow || newWindow.closed || typeof newWindow.closed === 'undefined') {
                showUserMessage('팝업이 차단되었습니다. 팝업 차단을 해제해주세요.', 'warning');
                // 팝업이 차단된 경우 같은 창에서 이동
                window.location.href = GOOGLE_SHEET_URL;
            }
        }
    } catch (error) {
        Logger.error('조건 입력 폼 이동 실패:', error);
        showUserMessage('페이지 이동 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.', 'error');
    }
}

/**
 * 사용자에게 메시지 표시
 * @param {string} message - 표시할 메시지
 * @param {string} type - 메시지 타입 ('info', 'warning', 'error', 'success')
 */
function showUserMessage(message, type) {
    type = type || 'info';
    
    // 간단한 토스트 메시지 생성
    const toast = document.createElement('div');
    toast.className = `toast-message toast-${type}`;
    toast.textContent = message;
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-live', 'polite');
    
    // 스타일 적용
    Object.assign(toast.style, {
        position: 'fixed',
        bottom: '20px',
        left: '50%',
        transform: 'translateX(-50%)',
        padding: '12px 24px',
        borderRadius: '8px',
        backgroundColor: type === 'error' ? '#ef4444' : type === 'warning' ? '#f59e0b' : type === 'success' ? '#10b981' : '#3b82f6',
        color: '#ffffff',
        fontSize: '14px',
        fontWeight: '500',
        zIndex: '10000',
        boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
        maxWidth: '90%',
        textAlign: 'center'
    });
    
    document.body.appendChild(toast);
    
    // 3초 후 자동 제거
    setTimeout(function() {
        toast.style.opacity = '0';
        toast.style.transition = 'opacity 0.3s ease';
        setTimeout(function() {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300);
    }, 3000);
}

/**
 * 로딩 상태 표시
 */
function showLoadingState() {
    // 간단한 로딩 인디케이터 (선택사항)
    const loader = document.createElement('div');
    loader.id = 'page-loader';
    loader.setAttribute('aria-label', '로딩 중');
    loader.setAttribute('role', 'status');
    loader.innerHTML = '<div class="spinner"></div>';
    
    Object.assign(loader.style, {
        position: 'fixed',
        top: '0',
        left: '0',
        width: '100%',
        height: '100%',
        backgroundColor: 'rgba(255, 255, 255, 0.9)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: '9999'
    });
    
    document.body.appendChild(loader);
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


