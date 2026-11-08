# 10장. PostgreSQL과 영속 스토리지 구성하기

예상 분량: 12쪽. 명령은 저장소 루트에서 실행합니다.

## 10-1. DB Pod와 영속 볼륨의 연결 구조

PostgreSQL·Service·StatefulSet·PVC·PV·StorageClass를 연결합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 10-2. StatefulSet과 스토리지 수명 이해하기

Pod 식별자·동적 프로비저닝·접근 모드·회수 정책을 배웁니다.

## 10-3. Secret과 PVC를 사용해 PostgreSQL 배포하기

DB를 배포하고 SQL로 저장합니다. 클라이언트 Service와 Headless Service를 구분합니다.

~~~sh
./scripts/korora.sh apply 10
./scripts/korora.sh k get statefulsets,pvc
./scripts/korora.sh k exec postgres-0 -- psql -U postgres -d korora -c "CREATE TABLE IF NOT EXISTS public.storage_probe(id int PRIMARY KEY); INSERT INTO public.storage_probe VALUES(1) ON CONFLICT DO NOTHING;"
./scripts/korora.sh k delete pod postgres-0
./scripts/korora.sh k rollout status statefulset/postgres --timeout=180s
./scripts/korora.sh k exec postgres-0 -- psql -U postgres -d korora -c "TABLE public.storage_probe;"
~~~

## 10-4. DB Pod 재생성 후 데이터 확인하기

Pod 교체 전후 데이터·PVC를 확인하고 Pod·볼륨·클러스터 수명을 구분합니다.

local-path 볼륨은 Pod 재생성 시 데이터를 유지하지만 클러스터 삭제까지 보호하는 백업은 아닙니다. 잘못된 StorageClass는 examples/diagnostics/missing-storageclass.yaml로 별도 PVC를 만들어 실습하고 직접 삭제합니다. Secret의 비밀번호를 바꿔도 기존 PostgreSQL 계정 비밀번호는 바뀌지 않습니다. wrong-db-password 적용 뒤 db-client.yaml을 새로 만들어 psql -c 'SELECT 1'로 인증 실패를 확인하고, 복구 후 클라이언트도 재생성합니다.

## 10-5. 잘못된 StorageClass와 접속 정보 사용하기

PVC Pending과 DB 인증 실패를 각각 조사합니다. 기존 볼륨을 지우지 않고 별도 예제로 실습합니다.

제공 시나리오: `wrong-db-password`.

~~~sh
./scripts/korora.sh fault 10 wrong-db-password
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 10
~~~

## 10-6. korora의 데이터 보존 범위 정하기

단일 DB 한계·로컬 볼륨 보존 범위·백업 대상·복구 기준을 기록합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
