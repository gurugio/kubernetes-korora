# 16장. Kustomize로 묶고 korora 완성하기

예상 분량: 18쪽. 명령은 저장소 루트에서 실행합니다.

## 16-1. 완성된 서비스와 배포 파일의 관계

최종 요청 흐름과 오브젝트 관리 관계를 각각 그립니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 16-2. base·overlay와 설정 변경의 영향 이해하기

리소스 조합·patch·ConfigMap/Secret 생성·이름 참조·롤아웃을 배웁니다.

## 16-3. korora 배포 패키지와 복구 절차 만들기

기본·미러링 overlay를 나누고 CronJob을 수동 실행하며 외부 백업과 별도 DB 복구를 실습합니다.

~~~sh
./scripts/korora.sh apply 16
python3 scripts/smoke-test.py --restart-db
./scripts/backup-restore.sh
./scripts/korora.sh k create job korora-backup-manual --from=cronjob/korora-backup
./scripts/korora.sh k wait --for=condition=complete job/korora-backup-manual --timeout=180s
./scripts/korora.sh k logs job/korora-backup-manual
kustomize build overlays/basic > .local/basic.yaml
./scripts/korora.sh k apply -f .local/basic.yaml
python3 scripts/smoke-test.py --no-mirror
./scripts/korora.sh apply 16
~~~

## 16-4. 처음부터 배포하고 완료 조건 검증하기

새 환경에서 안내·쓰기·조회·필터·미러링·영속성·정책·복구를 확인합니다.

CronJob은 suspend:true로 제공하며 명시적인 수동 Job만 실행합니다. 수동 Job 재실행 시 새 이름을 사용합니다. 백업 PVC도 로컬 클러스터 안에 있으므로 backup-restore.sh로 클러스터 밖 .local/backups에 백업하고 별도 DB로 복원합니다. 원본은 덮어쓰지 않습니다. overlays/basic은 Shadow 리소스를 유지하고 미러링 비율만 0으로 바꿉니다.

## 16-5. 설정 오류가 들어간 배포본 복구하기

잘못된 참조를 하나씩 주입하고 렌더링·이벤트·로그로 진단해 복구합니다.

제공 시나리오: `broken-secret-ref`.

~~~sh
./scripts/korora.sh fault 16 broken-secret-ref
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 16
~~~

## 16-6. korora의 설계 문서와 운영 절차 작성하기

구조도·설정표·권한표·장애 대응·백업/복구·제약·개선 과제를 정리합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
