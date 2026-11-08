# 7장. Envoy로 요청 경로 제어하기

예상 분량: 12쪽. 명령은 저장소 루트에서 실행합니다.

## 7-1. Ingress와 애플리케이션 사이에 Envoy 배치하기

Envoy Service·Pod 추가 전후의 요청 흐름을 비교합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 7-2. Listener·Route·Cluster 이해하기

요청 수신 지점·전달 규칙·업스트림·타임아웃의 관계를 배웁니다.

## 7-3. 경로에 따라 Nginx와 echo-server로 전달하기

Envoy ConfigMap을 제공하고 안내·진단·쓰기·조회 경로를 나눕니다.

~~~sh
./scripts/korora.sh apply 07
./scripts/http.sh /envoy-health
./scripts/http.sh /debug/
./scripts/http.sh /query/measurements
./scripts/korora.sh k logs deployment/envoy --tail=20
~~~

## 7-4. 어느 업스트림이 응답했는지 확인하기

응답과 접근 로그에서 경로·업스트림·재작성된 경로를 확인합니다.

7~10장의 Ingest와 Query는 echo-server입니다. 실제 저장은 11장, 실제 조회는 12장부터 추가됩니다. 각 단계의 이미지 변경은 patch 파일에서 확인합니다.

## 7-5. Cluster 이름과 업스트림 주소를 틀려 보기

설정 오류와 연결 실패를 구분하고 설정 검증·로그·응답을 조사합니다.

제공 시나리오: `invalid-envoy`.

~~~sh
./scripts/korora.sh fault 07 invalid-envoy
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 07
~~~

## 7-6. korora의 라우팅 표 작성하기

경로 우선순위·상태 확인 예외·접두어 제거 규칙을 정합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.

실제 요청을 받을 준비가 된 뒤 Service 대상으로 포함되도록 Envoy와 PostgREST에는 기본 readiness를 먼저 제공합니다. 13장에서 startup·liveness와의 차이 및 업데이트 정책을 확장해 학습합니다.
