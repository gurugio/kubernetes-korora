# 2장. 재현 가능한 로컬 실습 환경 만들기

예상 분량: 10쪽. 명령은 저장소 루트에서 실행합니다.

## 2-1. 내 컴퓨터와 Kubernetes 클러스터의 관계

호스트·컨테이너 런타임·k3d 노드·Pod·외부 접속 포트를 연결합니다.

[전체 구조도](../../README.md)를 바탕으로 이 장의 [kustomization.yaml](kustomization.yaml)에서 추가·변경된 연결을 표시합니다.

## 2-2. Node·Context·Namespace 이해하기

kubeconfig·Context·Namespace와 노드·Pod의 차이를 배웁니다.

## 2-3. k3d 클러스터와 korora Namespace 생성하기

버전을 고정한 클러스터를 만들고 Traefik·StorageClass·네트워크 정책 구성을 확인합니다.

~~~sh
./scripts/setup.sh
./scripts/korora.sh apply 02
./scripts/korora.sh k get nodes
./scripts/korora.sh k get pods -n kube-system
./scripts/korora.sh k get storageclass
~~~

## 2-4. 실습 준비 상태 확인하기

노드 Ready 상태, 시스템 Pod, Namespace와 kubectl 연결을 확인합니다.

## 2-5. 접속 포트와 Namespace를 잘못 지정해 보기

API 서버 접속 실패와 리소스를 찾지 못하는 상황을 구분하고 복구합니다.

## 2-6. korora의 실습 환경 기준 정하기

도구 버전·클러스터 이름·도메인·포트·디렉터리 구조를 정리합니다.

## 완료 기록

관찰한 응답·상태·로그, 고장 원인, 복구 확인 결과를 기록한 뒤 다음 장으로 진행합니다.
