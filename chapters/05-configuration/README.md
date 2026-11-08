# 5장. ConfigMap과 Secret으로 설정 분리하기

예상 분량: 10쪽. 명령은 저장소 루트에서 실행합니다.

## 5-1. 설정이 컨테이너에 전달되는 두 가지 경로

환경변수 주입과 파일 마운트, ConfigMap·Secret 연결 위치를 그립니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 5-2. 설정값·비밀값·이미지의 경계 정하기

각 오브젝트의 용도, 볼륨 마운트, Base64 표현과 암호화의 차이를 배웁니다.

## 5-3. Nginx 설정과 korora 안내 페이지 외부화하기

ConfigMap으로 Nginx 설정·HTML을 제공하고 예제 Secret 마운트를 확인합니다.

~~~sh
./scripts/korora.sh apply 05
./scripts/korora.sh k apply -f examples/diagnostics/secret-reader.yaml
./scripts/korora.sh k wait --for=condition=Ready pod/secret-reader --timeout=120s
./scripts/korora.sh k exec secret-reader -- test -s /run/korora/example-password
./scripts/korora.sh k get configmap
# index.html 수정 후 같은 장을 다시 적용해 ConfigMap 이름과 롤아웃을 비교합니다.
~~~

## 5-4. 설정 변경이 반영되는 시점 확인하기

환경변수·마운트 파일·프로세스 재로딩의 차이와 생성된 설정 이름을 확인합니다.

subPath 마운트는 실행 중인 컨테이너에 자동 갱신되지 않습니다. configMapGenerator의 내용 해시가 참조 이름을 바꾸어 Pod 교체를 유도합니다. 예제 비밀값은 출력하지 않고 파일 존재 여부만 확인합니다.

## 5-5. Secret 키와 ConfigMap 참조를 틀려 보기

존재하지 않는 키나 리소스를 참조해 컨테이너 시작 실패를 조사합니다.

제공 시나리오: `missing-config`, `missing-secret-key`.

~~~sh
./scripts/korora.sh fault 05 missing-config
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 05
~~~

## 5-6. korora의 설정 항목 분류하기

일반 설정은 ConfigMap, DB 비밀번호·TLS 개인 키는 Secret으로 분류합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
