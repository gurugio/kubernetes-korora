# 4장. Service와 DNS로 서버 연결하기

예상 분량: 10쪽. 명령은 저장소 루트에서 실행합니다.

## 4-1. Service가 Pod를 찾아 연결하는 구조

클라이언트·Service DNS·ClusterIP·EndpointSlice·대상 Pod를 연결합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 4-2. Service 종류와 포트의 관계 이해하기

ClusterIP·NodePort·Headless Service와 port·targetPort를 비교합니다.

## 4-3. Service 이름으로 여러 Pod에 접속하기

echo-server 복제본을 늘리고 진단용 Pod에서 DNS로 요청하며 EndpointSlice를 관찰합니다.

~~~sh
./scripts/korora.sh apply 04
./scripts/korora.sh k apply -f examples/diagnostics/pod.yaml
./scripts/korora.sh k wait --for=condition=Ready pod/diagnostics --timeout=120s
./scripts/korora.sh k exec diagnostics -- nslookup echo.korora.svc.cluster.local
./scripts/korora.sh k exec diagnostics -- nslookup echo-headless.korora.svc.cluster.local
./scripts/korora.sh k exec diagnostics -- wget -qO- http://echo/
./scripts/korora.sh k get endpointslices
~~~

## 4-4. Pod가 교체되어도 연결이 유지되는지 확인하기

Pod 교체 전후 IP와 Service 주소를 비교하고 내부 DNS를 확인합니다.

NodePort 30080은 노드 내부 포트입니다. 호스트에는 해당 포트 매핑을 만들지 않았습니다. 일반 Service는 ClusterIP, Headless Service는 Ready Pod 주소를 DNS로 제공합니다. 요청이 정확히 균등하게 분배되지는 않을 수 있습니다.

## 4-5. selector와 targetPort를 각각 틀려 보기

대상 Pod가 없는 경우와 포트 연결만 실패하는 경우를 구분합니다.

제공 시나리오: `wrong-selector`, `wrong-port`.

~~~sh
./scripts/korora.sh fault 04 wrong-selector
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 04
~~~

## 4-6. korora의 내부 주소와 Service 이름 정하기

구성 요소의 이름과 포트를 정하고 Pod IP를 직접 설정하지 않도록 합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
