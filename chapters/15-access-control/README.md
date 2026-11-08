# 15장. 최소 권한과 NetworkPolicy 적용하기

예상 분량: 12쪽. 명령은 저장소 루트에서 실행합니다.

## 15-1. 외부 요청·내부 통신·관리 권한의 경계

사용자 요청·Pod 통신·Kubernetes API 접근·DB 권한을 구분합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 15-2. ServiceAccount·RBAC·NetworkPolicy 이해하기

Role·RoleBinding·서비스 계정·정책 선택과 허용·DNS 예외를 배웁니다.

## 15-3. korora에 필요한 접근만 허용하기

조회 Role과 서비스 계정을 만들고 DB 통신·프록시 통신을 제한합니다.

~~~sh
./scripts/korora.sh apply 15
./scripts/korora.sh k auth can-i get pods --as=system:serviceaccount:korora:korora-reader
./scripts/korora.sh k auth can-i get secrets --as=system:serviceaccount:korora:korora-reader
# 각각 yes / no. no의 종료 코드 1은 예상한 결과입니다.
./scripts/http.sh '/query/measurements?limit=1' -H 'X-Korora-Client: policy-student'
./scripts/korora.sh k apply -f examples/diagnostics/pod.yaml
./scripts/korora.sh k wait --for=condition=Ready pod/diagnostics --timeout=120s
./scripts/korora.sh k exec diagnostics -- pg_isready -h postgres -t 3
# diagnostics -> DB는 차단되어 실패해야 합니다.
~~~

## 15-4. 허용·차단 결과를 실제로 확인하기

권한별 리소스 조회와 Pod 간 연결을 비교해 정책 강제 여부를 확인합니다.

기본 K3s 네트워크 정책 컨트롤러가 실제로 강제하는지 연결 실험으로 확인합니다. DNS 차단은 기존 캐시·열린 연결 때문에 늦게 드러날 수 있으므로 새 진단 프로세스에서 nslookup도 수행합니다. 허용 경로와 차단 경로를 같은 시점에 비교합니다.

## 15-5. DNS와 DB 접근을 실수로 차단해 보기

이름 해석 실패와 DB 연결 실패를 구분하고 빠진 허용 규칙을 복구합니다.

제공 시나리오: `block-dns`, `block-database`.

~~~sh
./scripts/korora.sh fault 15 block-dns
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 15
~~~

## 15-6. korora의 접근 제어 표 완성하기

주체·리소스·권한과 Pod·목적지·포트를 표로 정리합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
