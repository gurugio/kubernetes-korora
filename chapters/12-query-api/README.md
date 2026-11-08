# 12장. 데이터를 읽는 Query API 만들기

예상 분량: 10쪽. 명령은 저장소 루트에서 실행합니다.

## 12-1. 저장된 데이터가 조회 응답으로 돌아오는 흐름

조회 경로와 쓰기 API가 공유하는 DB를 표시합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 12-2. 읽기 전용 권한과 조회 조건 이해하기

필터·정렬·결과 제한·페이지 처리·빈 결과와 오류를 구분합니다.

## 12-3. 읽기 전용 PostgREST 배포하기

별도 DB 권한으로 Query API를 배포하고 장비·메트릭·시간 조건으로 조회합니다.

~~~sh
./scripts/korora.sh apply 12
./scripts/http.sh '/query/measurements?device=eq.sensor-01&order=observed_at.desc&limit=10' -H 'X-Korora-Client: student'
./scripts/http.sh '/query/measurements?device=eq.unknown' -H 'X-Korora-Client: student'
~~~

## 12-4. 쓰기부터 조회까지 한 번에 확인하기

저장 데이터와 조회 결과를 대조하고 읽기 API의 쓰기 거절을 확인합니다.

Query는 SELECT만 허용하고 최대 100행을 반환합니다. 정렬이 필요하면 order를 명시합니다. 빈 결과는 오류가 아닌 200과 []입니다. 프록시와 DB의 메서드/권한 제어를 각각 확인합니다.

## 12-5. 조회 권한과 필터 조건을 틀려 보기

권한 오류·잘못된 문법·정상적인 빈 결과·스키마 오류를 구분합니다.

제공 시나리오: `wrong-schema`.

~~~sh
./scripts/korora.sh fault 12 wrong-schema
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 12
~~~

## 12-6. korora의 조회 인터페이스 정리하기

기본 정렬·최대 조회량·허용 메서드·미러링 규칙을 확정합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.

실제 요청을 받을 준비가 된 뒤 Service 대상으로 포함되도록 Envoy와 PostgREST에는 기본 readiness를 먼저 제공합니다. 13장에서 startup·liveness와의 차이 및 업데이트 정책을 확장해 학습합니다.
