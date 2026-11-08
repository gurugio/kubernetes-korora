# 9장. 미러링으로 같은 요청을 다른 서버에 보내기

예상 분량: 12쪽. 명령은 저장소 루트에서 실행합니다.

## 9-1. 주 요청과 미러 요청이 갈라지는 구조

주 서버·Shadow로 분기되는 요청과 실제 응답 경로를 구분합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 9-2. 미러링과 응답 트래픽 분배 이해하기

복제 비율과 주 응답 선택 비율, Shadow 응답이 사용되지 않는 동작을 배웁니다.

## 9-3. 두 echo-server로 미러링 실습하기

서버 식별자를 구분하고 헤더·경로·본문의 전달을 관찰합니다.

~~~sh
./scripts/korora.sh apply 09
./scripts/http.sh /query/measurements -H 'X-Korora-Client: mirror-student'
./scripts/korora.sh k logs deployment/shadow --since=1m
~~~

## 9-4. 요청 수와 주 응답 출처 비교하기

충분한 요청 표본으로 복제 비율과 실제 주 응답을 비교합니다.

정상 구성은 조회 요청을 100% 복제하고 Query 응답만 사용합니다. mirror-off는 복제만 끕니다. response-split은 미러링 없이 주 응답을 Query 20%, Shadow 80%로 선택하는 비교 구성입니다. Shadow 지연 주입은 확장 과제입니다.

## 9-5. Shadow 서버를 중단하거나 느리게 만들기

제공된 중단 시나리오로 주 응답·프록시 로그·오류 지표를 관찰합니다. 지연 주입은 확장 과제로 둡니다.

제공 시나리오: `shadow-down`, `mirror-off`, `response-split`.

~~~sh
./scripts/korora.sh fault 09 shadow-down
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 09
~~~

## 9-6. korora의 미러링 대상과 제외 경로 정하기

DB 연결 이후 조회 경로만 복제하고 쓰기·상태 확인 경로는 제외합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
