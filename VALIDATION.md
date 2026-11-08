# 검증 결과

검증일: 2026-11-08. 대상은 이 자료를 위해 새로 생성한 로컬 `k3d-korora` 클러스터입니다.

## 작성 범위

- 교재 계획: 서문 4쪽 + 본문 184쪽 + 부록 12쪽 = 200쪽.
- 16장, 세부 절 96개와 장별 README.
- 장별 누적 Kustomize 구성, 21개 고장·비교 시나리오, 최종 overlay 2개.
- Kubernetes 리소스 외에 OpenAPI·k3d·Envoy·Prometheus 설정도 YAML로 제공합니다.
- 개별 컴포넌트는 components/에 두고 각 장이 필요한 구성을 참조합니다.

## 정적 검증

| 항목 | 결과 |
| --- | --- |
| 정상 16장 + 고장 21개 + overlay 2개 + 루트 구성 | 40개 모두 Kustomize 렌더링 성공 |
| Kubernetes 1.33.0 strict 스키마 | 리소스 문서 967개 Valid, Invalid 0, Error 0, Skip 0 |
| Envoy v1.36.2 자체 설정 검사 | envoy.yaml 8개 모두 --mode validate 통과 |
| YAML 중복 키·생성된 참조·이미지 태그 검사 | 통과 |
| Python·POSIX shell 문법 검사 | 통과 |
| README 목차 | 16장·96개 절 확인 |

967개는 40개 구성에 반복 포함된 리소스를 합산한 수입니다. 완성 구성 자체는 49개 Kubernetes 리소스로 렌더링됩니다. 1장은 설계 실습이므로 배포 리소스가 0개입니다.

## 로컬 실행 검증

환경: Rancher Desktop의 로컬 Docker, k3d v5.8.3, K3s v1.33.6+k3s1, arm64.

| 항목 | 결과 |
| --- | --- |
| 2~16장의 누적 배포 흐름 | 각 단계 기동·롤아웃 확인 |
| 도메인·TLS | korora.test 인증서를 명시적으로 신뢰한 HTTPS 성공 |
| Envoy 경로 재작성 | /query/measurements → /measurements 확인 |
| 필수 헤더 누락·형식 오류 | HTTP 400 확인 |
| 허용하지 않은 API 메서드 | HTTP 405 확인 |
| 내부 헤더 위조 | X-Korora-Internal이 envoy로 덮어써짐 |
| 쓰기·중복 방지 | 신규 이벤트 201, 동일 event_id 409 |
| 조회·빈 결과 | 저장한 값과 정상 빈 배열 확인 |
| DB 권한 | writer INSERT 허용·SELECT 거절, reader SELECT 허용·INSERT 거절 |
| 조회 미러링 | Shadow에서 조회 마커 확인, 쓰기 마커는 없음 |
| basic overlay | 조회·쓰기 마커 모두 Shadow에 전달되지 않음 |
| 영속성 | PostgreSQL Pod 재생성 후 저장한 이벤트 조회 성공 |
| 논리 백업·복구 | 클러스터 밖 덤프 생성, 별도 DB 복원, 원본·복구본 각 2행 일치 |
| 백업 CronJob | suspend 상태의 CronJob에서 수동 Job 생성·완료 |
| RBAC | reader의 pods 조회 yes, secrets 조회 no |
| NetworkPolicy | diagnostics → DB 차단, 공개 Query 경로는 같은 시점에 성공 |
| 메트릭 발견 | Headless Service DNS로 발견한 Envoy Pod 2개 모두 UP |
| Secret 참조 고장 | CreateContainerConfigError 관찰 후 정상 구성 재적용·복구 |

실행한 주요 명령:

~~~sh
python3 scripts/validate.py
kubeconform -strict -summary -kubernetes-version 1.33.0 -cache .local/schema-cache .local/rendered/
python3 scripts/smoke-test.py --restart-db
./scripts/backup-restore.sh
python3 scripts/smoke-test.py --no-mirror
~~~

## 발견 후 수정한 사항

- 고장 구성이 부모 장을 참조할 때 발생한 Kustomize 순환 참조 오류: faults/를 장과 분리.
- 고정 Envoy 버전의 RE2 크기 제한: 헤더 정규식을 단순화.
- 고정 버전에서 지원하지 않는 선택적 미러링 필드: 제거.
- 헤더가 아예 없는 경우의 matcher 동작: 빈 값으로 간주하도록 명시하고 실제 HTTP 400 재검증.
- 중간 장을 바로 배포할 때의 준비 상태: Envoy·PostgREST 기본 readiness 제공.
- 복제본별 메트릭 수집: ClusterIP 단일 대상 대신 Headless Service DNS로 Pod별 수집.
- 메트릭 고장 시나리오: DNS 발견 방식의 수집 포트를 잘못 지정하도록 수정.

9장 초기 롤아웃 직후 요청 timeout을 한 차례 관찰했습니다. 이후 직접 연결과 Ingress 경유 HTTP/1.1·HTTP/2 재검증은 정상이며, 완성본과 두 overlay의 검증을 통과했습니다. 해당 현상의 단일 원인을 확정한 것은 아닙니다.

## 미실행 범위와 한계

- 21개 고장·비교 시나리오 전부의 개별 런타임 재현은 수행하지 않았습니다. 전부 렌더링·스키마 검사를 했고 Secret 참조 고장·복구와 미러링 중지는 실행했습니다.
- 장시간 안정성·부하, 롤아웃 중 연속 트래픽의 무중단 보장, 멀티노드 DB 장애 복구는 검증 범위에 포함하지 않았습니다.
- Shadow 지연 주입은 교재의 확장 과제이며 별도 지연용 YAML은 제공하지 않습니다.
- 외부 DNS·공인 인증서·관리형 클라우드 로드밸런서는 사용하지 않았습니다. 로컬 도메인 연결과 자체 서명 TLS로 실습합니다.
- DB는 단일 인스턴스이며 local-path와 백업 PVC 자체는 클러스터 삭제에 대한 보호 수단이 아닙니다.

## 검증 환경 정리

검증용으로 생성한 korora 클러스터·노드·네트워크·클러스터 볼륨을 삭제했습니다. 기본 kubeconfig를 사용하지 않고 전용 .local/kubeconfig를 지정했습니다. 전용 kubeconfig·진행 기록도 정리하여 새 실습은 2장부터 시작할 수 있습니다.

README·YAML·실행 스크립트·정적 검증 출력과 클러스터 밖 .local/backups의 예제 백업은 보존했습니다. 다시 실행하려면 ./scripts/setup.sh를 사용합니다.
