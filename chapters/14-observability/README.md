# 14장. 로그와 메트릭으로 장애 원인 찾기

예상 분량: 10쪽. 명령은 저장소 루트에서 실행합니다.

## 14-1. 요청과 관측 데이터가 흐르는 구조

프록시 로그·API 로그·DB 오류·Envoy 메트릭의 발생 지점을 표시합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 14-2. 접근 로그·요청 ID·메트릭 이해하기

HTTP 상태·업스트림 오류·지연·요청 수·오류율·민감 정보 기록을 다룹니다.

## 14-3. 요청 하나를 여러 로그에서 추적하기

요청 ID를 전달하고 로그를 비교하며 Prometheus로 Envoy 지표를 수집합니다.

~~~sh
./scripts/korora.sh apply 14
./scripts/http.sh '/query/measurements?limit=1' -H 'X-Korora-Client: observer'
./scripts/korora.sh k logs deployment/envoy --tail=20
./scripts/korora.sh k logs deployment/query --tail=20
./scripts/korora.sh k port-forward service/prometheus 19090:9090
# 다른 터미널: http://127.0.0.1:19090/targets
~~~

## 14-4. 정상 요청과 실패 요청의 증거 비교하기

카운터 변화와 오류 로그·지표의 상관관계를 확인합니다.

Prometheus는 Headless Service envoy-metrics의 DNS로 각 Envoy Pod IP를 발견해 9901을 개별 수집합니다. 관리·메트릭 포트는 외부 Ingress에 연결하지 않습니다. 시계열 저장은 교육용 emptyDir입니다. 예시 PromQL: sum(rate(envoy_http_downstream_rq_total[1m])).

## 14-5. 업스트림 연결 실패를 단계별로 조사하기

DNS → Service → Endpoint → 포트 → 애플리케이션 → DB 순서로 좁혀 갑니다.

제공 시나리오: `wrong-scrape-port`.

~~~sh
./scripts/korora.sh fault 14 wrong-scrape-port
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 14
~~~

## 14-6. korora의 기본 관측 항목 정하기

최소 로그·핵심 지표·오류 증가 시 진단 절차를 작성합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
