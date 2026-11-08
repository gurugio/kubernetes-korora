# 13장. 상태 검사와 롤링 업데이트로 서비스 유지하기

예상 분량: 12쪽. 명령은 저장소 루트에서 실행합니다.

## 13-1. Pod 상태와 트래픽 대상의 관계

Probe·Ready·Service Endpoint·종료 중 Pod의 관계를 그립니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 13-2. Probe·리소스·업데이트 전략 이해하기

startup·readiness·liveness·requests·limits·RollingUpdate·종료 유예·PDB를 배웁니다.

## 13-3. 상태 검사를 추가하고 요청 중 업데이트하기

복제본과 Probe를 구성하고 연속 요청 중 설정 변경·롤아웃을 진행합니다.

~~~sh
./scripts/korora.sh apply 13
./scripts/korora.sh k get pods,pdb
./scripts/korora.sh k rollout restart deployment/query
./scripts/korora.sh k rollout status deployment/query --timeout=180s
# 다른 터미널에서 HTTP 조회를 반복하며 업데이트 중 응답을 기록합니다.
~~~

## 13-4. 요청 성공률과 Pod 교체 과정 확인하기

Ready·Endpoint 변경 시점과 요청 실패 여부를 관찰합니다.

PDB는 자발적 중단을 제한합니다. Deployment 롤아웃 중 가용성은 maxUnavailable/maxSurge로 제어합니다. API의 /live와 /ready는 3001 관리 포트를 사용하며 외부 Service에는 공개하지 않습니다.

## 13-5. 상태 검사 경로와 리소스 요청을 틀려 보기

재시작 반복과 스케줄링 Pending을 구분하고 복구합니다.

제공 시나리오: `bad-liveness`, `unschedulable`.

~~~sh
./scripts/korora.sh fault 13 bad-liveness
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 13
~~~

## 13-6. korora 구성 요소별 운영 기준 정하기

상태 검사·종료 정책을 정하고 외부 의존성 장애와 프로세스 장애를 구분합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
