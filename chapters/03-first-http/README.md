# 3장. Nginx와 echo-server 배포하기

예상 분량: 10쪽. 명령은 저장소 루트에서 실행합니다.

## 3-1. Deployment가 Pod를 유지하는 구조

Deployment → ReplicaSet → Pod 관리 관계와 HTTP 서버를 그립니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 3-2. 이미지·Pod·ReplicaSet·Deployment 이해하기

선언적 설정·복제본 수·label·selector·이미지 버전 고정을 배웁니다.

## 3-3. 두 종류의 HTTP 서버 배포하기

Nginx와 echo-server를 배포하고 port-forward로 접속해 로그를 확인합니다.

~~~sh
./scripts/korora.sh apply 03
./scripts/korora.sh k get deployments,replicasets,pods
./scripts/korora.sh k port-forward deployment/web 18080:8080
# 다른 터미널: curl http://127.0.0.1:18080/
~~~

## 3-4. Pod 삭제 후 자동 복구 확인하기

Pod 삭제 후 새 Pod가 생성되고 복제본 수가 유지되는지 확인합니다.

## 3-5. 존재하지 않는 이미지 태그 사용하기

ImagePullBackOff를 발생시키고 상태·이벤트·설정에서 원인을 찾습니다.

제공 시나리오: `bad-image`.

~~~sh
./scripts/korora.sh fault 03 bad-image
./scripts/korora.sh k get pods
./scripts/korora.sh k get events --sort-by=.lastTimestamp
# YAML 구성 복구
./scripts/korora.sh apply 03
~~~

## 3-6. korora의 무상태 서버 운영 방식 정하기

서버를 Deployment로 관리하는 이유와 영속 데이터를 분리하는 원칙을 정합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
