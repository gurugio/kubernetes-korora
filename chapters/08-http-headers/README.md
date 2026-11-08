# 8장. HTTP 헤더 검사와 전달 규칙 만들기

예상 분량: 12쪽. 명령은 저장소 루트에서 실행합니다.

## 8-1. 프록시를 거치며 헤더가 바뀌는 과정

클라이언트 헤더와 프록시가 추가·수정하는 헤더를 구분합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 8-2. 헤더 필터링과 인증·인가의 관계 이해하기

형식 검사와 신원 검증의 차이, Host·전달 헤더의 역할을 배웁니다.

## 8-3. 요청을 검사하고 추적 헤더 추가하기

X-Korora-Client 조건과 내부 헤더 덮어쓰기를 구성합니다.

~~~sh
./scripts/korora.sh apply 08
./scripts/http.sh /query/measurements -i
./scripts/http.sh /query/measurements -i -H 'X-Korora-Client: student'
./scripts/http.sh /debug/ -H 'X-Korora-Internal: forged'
~~~

## 8-4. 허용·거절·헤더 변경 결과 확인하기

정상·누락·잘못된 값의 응답과 echo-server가 받은 값을 비교합니다.

X-Korora-Client는 형식 검사 실습용 헤더로 사용자 인증을 제공하지 않습니다. /debug/는 헤더 관찰용 경로입니다. X-Korora-Internal은 정상 구성에서 envoy로 덮어씁니다.

## 8-5. 클라이언트가 내부 헤더를 위조해 보기

내부 헤더를 직접 보내고 덮어쓰기 규칙과 프록시 신뢰 범위를 점검합니다.

제공 시나리오: `trust-client-header`.

~~~sh
./scripts/korora.sh fault 08 trust-client-header
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 08
~~~

## 8-6. korora의 요청 헤더 정책 작성하기

필수 헤더·프록시 신뢰 범위·민감 로그 제외·실제 인증 필요 지점을 정리합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
