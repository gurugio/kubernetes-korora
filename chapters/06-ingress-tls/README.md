# 6장. Ingress와 TLS로 외부 요청 받기

예상 분량: 14쪽. 명령은 저장소 루트에서 실행합니다.

## 6-1. 도메인에서 내부 Service까지의 진입 경로

이름 해석·호스트 포트·Controller·Service·Pod와 TLS 종료 지점을 표시합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 6-2. DNS·Ingress·Controller·TLS 이해하기

Ingress와 Controller의 역할, Host·경로·인증서·SNI를 배웁니다.

## 6-3. korora.test를 HTTPS로 연결하기

Traefik Ingress와 로컬 인증서를 연결하고 HTTP·HTTPS를 비교합니다.

~~~sh
./scripts/korora.sh apply 06
./scripts/http.sh / -i
curl --noproxy '*' --resolve korora.test:8080:127.0.0.1 http://korora.test:8080/
~~~

## 6-4. Host 라우팅과 인증서 확인하기

안내 페이지, 인증서 이름과 TLS 종료 위치를 검사합니다.

TLS는 Traefik에서 종료됩니다. 인증서는 로컬 교육용 자체 서명 인증서이며 http.sh가 tls.crt를 명시적으로 신뢰합니다. HTTP 자동 리다이렉트는 설정하지 않았습니다.

## 6-5. Host·인증서·백엔드 이름을 틀려 보기

라우팅 실패·인증서 이름 불일치·잘못된 Service 참조를 조사합니다.

제공 시나리오: `wrong-host`, `wrong-backend`.

~~~sh
./scripts/korora.sh fault 06 wrong-host
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 06
~~~

## 6-6. korora의 외부 접속 규칙 정하기

공개 도메인·경로·HTTP 처리 정책·인증서 갱신 책임을 정리합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
