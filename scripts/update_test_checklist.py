#!/usr/bin/env python3
"""
테스트 체크리스트 자동 업데이트 스크립트

QA_TEST_SCENARIOS.md 파일의 체크리스트를 자동으로 업데이트합니다.
테스트 결과 파일(TEST_RESULTS.md)을 읽어서 체크리스트를 업데이트할 수 있습니다.

사용법:
    python scripts/update_test_checklist.py --test-case TC-001 --status pass
    python scripts/update_test_checklist.py --file test_results.json
    python scripts/update_test_checklist.py --interactive
"""

import re
import sys
import os
import json
import argparse
from pathlib import Path

# 프로젝트 루트 디렉토리
PROJECT_ROOT = Path(__file__).parent.parent
QA_SCENARIOS_FILE = PROJECT_ROOT / "_AI_Doc" / "QA_TEST_SCENARIOS.md"
TEST_RESULTS_FILE = PROJECT_ROOT / "_AI_Doc" / "TEST_RESULTS.md"


def read_file(file_path):
    """파일 읽기"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        print(f"오류: 파일을 찾을 수 없습니다: {file_path}")
        sys.exit(1)
    except Exception as e:
        print(f"오류: 파일 읽기 실패: {e}")
        sys.exit(1)


def write_file(file_path, content):
    """파일 쓰기"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ 파일 업데이트 완료: {file_path}")
    except Exception as e:
        print(f"오류: 파일 쓰기 실패: {e}")
        sys.exit(1)


def update_checklist_item(content, test_case_id, status):
    """
    체크리스트 항목 업데이트
    
    Args:
        content: 파일 내용
        test_case_id: 테스트 케이스 ID (예: TC-001)
        status: 상태 ('pass', 'fail', 'blocked', 'not_run')
    
    Returns:
        업데이트된 파일 내용
    """
    # 체크박스 패턴: - [ ] TC-XXX: 설명
    pattern = rf'(- \[ \]) ({re.escape(test_case_id)}:.*)'
    
    if status == 'pass':
        replacement = r'- [x] \2'
    elif status in ('fail', 'blocked', 'not_run'):
        replacement = r'- [ ] \2'
    else:
        print(f"경고: 알 수 없는 상태: {status}")
        return content
    
    # 단일 테스트 케이스 업데이트
    new_content = re.sub(pattern, replacement, content)
    
    if new_content == content:
        # 범위 테스트 케이스 처리 (예: TC-002~TC-007)
        range_pattern = rf'(- \[ \]) ({re.escape(test_case_id)}~.*)'
        new_content = re.sub(range_pattern, replacement, content)
    
    if new_content == content:
        print(f"경고: 테스트 케이스를 찾을 수 없습니다: {test_case_id}")
        return content
    
    print(f"✅ {test_case_id} 업데이트: {status}")
    return new_content


def update_from_json(json_file):
    """JSON 파일에서 테스트 결과 읽어서 체크리스트 업데이트"""
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"오류: 파일을 찾을 수 없습니다: {json_file}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"오류: JSON 파싱 실패: {e}")
        sys.exit(1)
    
    content = read_file(QA_SCENARIOS_FILE)
    
    # JSON 데이터에서 테스트 결과 추출
    if isinstance(data, list):
        for item in data:
            test_case_id = item.get('test_case_id', '')
            status = item.get('status', '').lower()
            if test_case_id and status:
                content = update_checklist_item(content, test_case_id, status)
    elif isinstance(data, dict):
        for test_case_id, status in data.items():
            content = update_checklist_item(content, test_case_id, status.lower())
    
    write_file(QA_SCENARIOS_FILE, content)


def update_from_test_results():
    """TEST_RESULTS.md 파일에서 테스트 결과 읽어서 체크리스트 업데이트"""
    content = read_file(TEST_RESULTS_FILE)
    qa_content = read_file(QA_SCENARIOS_FILE)
    
    # TEST_RESULTS.md에서 상태 추출
    # 패턴: **상태**: [x] PASS / [ ] FAIL / [ ] BLOCKED
    pattern = r'### (TC-\d+):.*?\*\*상태\*\*:.*?\[([x ])\].*?PASS.*?\[([x ])\].*?FAIL.*?\[([x ])\].*?BLOCKED'
    
    matches = re.finditer(pattern, content, re.DOTALL)
    
    updated = False
    for match in matches:
        test_case_id = match.group(1)
        pass_checked = match.group(2) == 'x'
        fail_checked = match.group(3) == 'x'
        blocked_checked = match.group(4) == 'x'
        
        if pass_checked:
            qa_content = update_checklist_item(qa_content, test_case_id, 'pass')
            updated = True
        elif fail_checked:
            qa_content = update_checklist_item(qa_content, test_case_id, 'fail')
            updated = True
        elif blocked_checked:
            qa_content = update_checklist_item(qa_content, test_case_id, 'blocked')
            updated = True
    
    if updated:
        write_file(QA_SCENARIOS_FILE, qa_content)
    else:
        print("경고: 업데이트할 테스트 결과를 찾을 수 없습니다.")


def interactive_mode():
    """대화형 모드"""
    print("=" * 50)
    print("테스트 체크리스트 업데이트 (대화형 모드)")
    print("=" * 50)
    print()
    
    content = read_file(QA_SCENARIOS_FILE)
    
    while True:
        test_case_id = input("테스트 케이스 ID 입력 (예: TC-001, 종료: q): ").strip()
        
        if test_case_id.lower() == 'q':
            break
        
        if not test_case_id.startswith('TC-'):
            print("경고: 테스트 케이스 ID는 'TC-'로 시작해야 합니다.")
            continue
        
        print("\n상태 선택:")
        print("1. PASS (통과)")
        print("2. FAIL (실패)")
        print("3. BLOCKED (차단)")
        print("4. NOT RUN (미실행)")
        print("5. 취소")
        
        choice = input("선택 (1-5): ").strip()
        
        status_map = {
            '1': 'pass',
            '2': 'fail',
            '3': 'blocked',
            '4': 'not_run',
            '5': None
        }
        
        status = status_map.get(choice)
        
        if status is None:
            if choice == '5':
                continue
            print("경고: 잘못된 선택입니다.")
            continue
        
        content = update_checklist_item(content, test_case_id, status)
        print()
    
    write_file(QA_SCENARIOS_FILE, content)
    print("\n✅ 체크리스트 업데이트 완료!")


def main():
    parser = argparse.ArgumentParser(
        description='QA 테스트 체크리스트 자동 업데이트 스크립트'
    )
    
    parser.add_argument(
        '--test-case', '-t',
        help='테스트 케이스 ID (예: TC-001)'
    )
    
    parser.add_argument(
        '--status', '-s',
        choices=['pass', 'fail', 'blocked', 'not_run'],
        help='테스트 상태'
    )
    
    parser.add_argument(
        '--file', '-f',
        help='JSON 파일에서 테스트 결과 읽기'
    )
    
    parser.add_argument(
        '--from-results', '-r',
        action='store_true',
        help='TEST_RESULTS.md 파일에서 테스트 결과 읽기'
    )
    
    parser.add_argument(
        '--interactive', '-i',
        action='store_true',
        help='대화형 모드'
    )
    
    args = parser.parse_args()
    
    if args.interactive:
        interactive_mode()
    elif args.test_case and args.status:
        content = read_file(QA_SCENARIOS_FILE)
        content = update_checklist_item(content, args.test_case, args.status)
        write_file(QA_SCENARIOS_FILE, content)
    elif args.file:
        update_from_json(args.file)
    elif args.from_results:
        update_from_test_results()
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()

