# 11장. 데이터를 저장하는 Ingest API 만들기

예상 분량: 12쪽. 명령은 저장소 루트에서 실행합니다.

## 11-1. HTTP 쓰기 요청에서 INSERT까지의 흐름

Envoy → Ingest → PostgREST → PostgreSQL 경로와 권한 경계를 표시합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 11-2. PostgREST·DB Role·Job 이해하기

테이블 API·DB 권한·초기화 Job과 반복 실행 시 고려할 점을 배웁니다.

## 11-3. 스키마와 쓰기 전용 API 구성하기

Job으로 테이블·권한을 만들고 PostgREST를 배포해 JSON 데이터를 저장합니다.

~~~sh
./scripts/korora.sh apply 11
./scripts/korora.sh k logs job/korora-schema-v1
./scripts/http.sh /ingest/measurements -i -X POST -H 'X-Korora-Client: student' -H 'Content-Type: application/json' --data-binary @examples/measurement.json
./scripts/korora.sh k exec postgres-0 -- psql -U postgres -d korora -c 'TABLE api.measurements;'
~~~

## 11-4. HTTP 응답과 DB 저장 결과 대조하기

성공 응답·실제 행·필수 필드 누락·자료형 오류·중복 이벤트를 확인합니다.

쓰기 계정은 INSERT만 허용합니다. Prefer: return=representation은 사용하지 않습니다. 같은 event_id를 재전송하면 409입니다. 초기화 Job은 완료 후 자동 재실행되지 않습니다. SQL로 권한을 제거했다면 GRANT INSERT ON api.measurements TO korora_writer로 복구하거나 초기화 Job을 명시적으로 다시 실행합니다. YAML 재적용만으로 DB 내부 변경을 복구할 수는 없습니다.

## 11-5. INSERT 권한과 이벤트 식별자를 깨뜨려 보기

권한 제거·잘못된 접속 정보·중복 event_id로 실패 원인을 확인합니다.

제공 시나리오: `wrong-db-login`.

~~~sh
./scripts/korora.sh fault 11 wrong-db-login
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 11
~~~

## 11-6. korora의 쓰기 계약과 재시도 규칙 정하기

허용 메서드·입력 제약·중복 처리·재시도 영향을 정리합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.

실제 요청을 받을 준비가 된 뒤 Service 대상으로 포함되도록 Envoy와 PostgREST에는 기본 readiness를 먼저 제공합니다. 13장에서 startup·liveness와의 차이 및 업데이트 정책을 확장해 학습합니다.
