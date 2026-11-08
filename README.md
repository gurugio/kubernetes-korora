# korora로 배우는 Kubernetes 백엔드 구축

korora는 뉴질랜드 마오리어로 쇠푸른펭귄을 뜻하는 **Kororā**에서 유래한 교육용 서비스 이름입니다.

공개 오픈소스 제품으로 측정 데이터의 저장·조회 서비스를 만들며 Kubernetes 기반 백엔드의 배포, 네트워크, 프록시, 데이터 영속성, 관측과 접근 제어를 익힙니다. 특정 회사나 내부 시스템을 전제로 하지 않습니다.

이 README는 **약 200쪽 분량의 교재 집필 계획**과 실행 가능한 장별 실습 예제의 안내입니다. 본문 원고 전체를 작성한 것은 아닙니다.

## 학습 대상과 진행 방식

기본 HTTP와 Linux 명령어를 아는 입문자를 대상으로 합니다. 각 장의 세부 절은 다음 순서를 따릅니다.

1. 이번 장의 구조도
2. 필요한 개념
3. 실습
4. 예상 결과
5. 일부러 고장 내보기
6. korora에서는 어떻게 사용하는가

전체 YAML은 예제 디렉터리에 제공하고 교재 본문에는 핵심 필드와 변경 부분을 설명합니다. 고장 실습은 한 가지씩 적용하고 관찰 증거와 복구 결과를 기록합니다. 이미지와 도구 버전은 고정합니다.

## 완성 구조

~~~mermaid
flowchart TD
    C[클라이언트] -->|HTTPS| T[Traefik Ingress Controller]
    T --> ES[Envoy Service]
    ES --> E[Envoy Pod]
    E -->|안내 페이지| WS[Web Service]
    WS --> W[Nginx Pod]
    E -->|쓰기| IS[Ingest Service]
    IS --> I[PostgREST 쓰기용]
    E -->|조회| QS[Query Service]
    QS --> Q[PostgREST 읽기용]
    E -. 조회 복제 .-> SS[Shadow Service]
    SS --> S[echo-server]
    I --> DS[Database Service]
    Q --> DS
    DS --> P[PostgreSQL StatefulSet의 Pod]
    P --> V[PVC와 영속 볼륨]
~~~

DNS는 korora.test를 진입 주소로 해석합니다. 실습에서는 hosts 변경 없이 curl --resolve를 사용합니다. 요청은 Service가 선택한 Pod로 전달되며 Deployment는 ReplicaSet을 통해 Pod를 관리합니다. Headless Service는 일반 Service와 DNS 동작이 다릅니다.

### 데이터와 API

| 필드 | 의미 |
| --- | --- |
| event_id | 중복 요청을 구분하는 UUID |
| device | 데이터를 보낸 장비 |
| metric | 측정 항목 |
| observed_at | 측정 시각 |
| value | 측정값 |

- 쓰기: POST /ingest/measurements
- 조회: GET /query/measurements?device=eq.sensor-01&order=observed_at.desc&limit=10
- Envoy가 /ingest/와 /query/ 접두어를 제거하여 PostgREST의 /measurements로 전달합니다.
- API 요청에는 X-Korora-Client: student 헤더를 사용합니다. 형식 검사이며 사용자 인증은 아닙니다.
- 쓰기·조회 API는 독립 배포하고 DB는 공유합니다. 쓰기는 INSERT, 조회는 SELECT만 허용합니다.
- DB 단일 인스턴스 구성입니다. 영속 볼륨·백업·고가용성은 서로 다른 역할입니다.
- 7~10장의 API는 echo-server이며 11장부터 저장, 12장부터 조회 기능을 붙입니다.

### 제품 구성

| 역할 | 제품·버전 |
| --- | --- |
| 로컬 Kubernetes | k3d v5.8.3, rancher/k3s:v1.33.6-k3s1 |
| Ingress Controller | 고정된 K3s 배포판에 포함된 Traefik |
| 프록시 | envoyproxy/envoy:v1.36.2 |
| 안내 페이지 | nginxinc/nginx-unprivileged:1.28.0-alpine |
| 요청 관찰·Shadow | mendhak/http-https-echo:37 |
| REST API | postgrest/postgrest:v12.2.3 |
| DB | postgres:17.6-alpine |
| 관측 | prom/prometheus:v3.2.1 |
| 배포 구성 | Kustomize v5 계열 |

## 디렉터리

~~~text
chapters/01-.../           설계·API 계약
chapters/02-.../k3d.yaml   로컬 클러스터 구성
chapters/03-.../ ...      장별 누적 Kustomize 구성과 README
faults/NN-*/        정상 리소스를 수정하는 고장·비교 시나리오
components/              공통 애플리케이션·설정·DB·백업 구성
overlays/basic/          최종 구성, 조회 미러링 비율 0
overlays/with-shadow/    최종 구성, 조회 미러링 비율 100
examples/               요청 데이터·독립 진단 리소스
scripts/                로컬 실행·렌더링 검증·HTTP 검증·백업 복구
.local/                 전용 kubeconfig·렌더링 결과·백업, Git 제외
~~~

각 장은 앞 장을 참조하는 **누적 스냅샷**입니다. 중간 장이나 16장을 바로 배포할 수 있습니다. 과거 장을 다시 적용해도 뒤 장에서 생성한 리소스가 자동 삭제되지는 않으므로 실행 도우미는 진도를 뒤로 되돌리는 적용을 거절합니다. 같은 장의 고장 복구는 가능합니다. 처음부터 실습하려면 별도 로컬 클러스터로 시작합니다.

## 빠른 실행

필수 도구: 로컬 Docker 엔진, k3d, kubectl, Kustomize v5, Python 3와 PyYAML. 정적 Kubernetes 스키마 검사에는 kubeconform을 추가로 사용합니다. Docker 엔진이 준비되어 있어야 합니다. 실행 스크립트는 로컬 unix Docker socket과 전용 로컬 API 서버만 사용하며 기본 kubeconfig를 변경하지 않습니다.

~~~sh
./scripts/setup.sh

# 순서대로 진행
./scripts/korora.sh apply 03
./scripts/korora.sh apply 04

# 완성본으로 바로 진행할 수도 있습니다.
./scripts/korora.sh apply 16

./scripts/http.sh /
./scripts/http.sh /ingest/measurements -i -X POST \
  -H 'X-Korora-Client: student' \
  -H 'Content-Type: application/json' \
  --data-binary @examples/measurement.json
./scripts/http.sh '/query/measurements?device=eq.sensor-01&limit=10' \
  -H 'X-Korora-Client: student'

python3 scripts/smoke-test.py --restart-db
./scripts/backup-restore.sh
~~~

같은 샘플을 다시 저장하면 event_id 중복으로 409가 예상됩니다. 전체 검증 스크립트는 매번 새 UUID를 사용합니다.

외부 주소는 https://korora.test:8443이며 HTTP는 8080입니다. TLS는 Traefik에서 종료하고 내부에는 HTTP로 전달합니다. 제공 인증서와 비밀번호는 **로컬 교육용 예제**입니다. 자체 서명 인증서는 http.sh가 동봉된 tls.crt로 검증합니다. HTTP 자동 리다이렉트는 구성하지 않았습니다.

### 고장 주입과 복구

~~~sh
./scripts/korora.sh apply 09
./scripts/korora.sh fault 09 shadow-down
./scripts/http.sh /query/measurements -H 'X-Korora-Client: student'
./scripts/korora.sh k logs deployment/envoy --tail=20
./scripts/korora.sh apply 09
~~~

이미 10장 이상으로 진행했다면 해당 장의 고장 시나리오를 사용하거나 새 실습 환경에서 9장을 시작합니다. 고장 구성은 정상 리소스에 대한 patch로 분리되어 있습니다. DB 안의 SQL 변경, PVC 삭제, 별도로 만든 진단 리소스는 정상 YAML 재적용만으로 복구되지 않습니다.

### 검증

~~~sh
# 클러스터 없이 모든 정상·고장·overlay 렌더링 및 참조 검사
python3 scripts/validate.py

# validate.py가 만든 Kubernetes 리소스만 스키마 검사
kubeconform -strict -summary -kubernetes-version 1.33.0 .local/rendered/

# 실제 완성본 HTTP·DB 권한·미러링·영속성 검사
python3 scripts/smoke-test.py --restart-db
~~~

01장의 OpenAPI·요청 예제, 02장의 k3d 설정, Envoy·Prometheus 설정 파일은 Kubernetes API 리소스가 아닙니다. kubeconform에는 원본 디렉터리 전체가 아닌 렌더링 결과를 전달합니다. 실제 검증 범위와 결과는 [VALIDATION.md](VALIDATION.md)에 기록합니다.

### 초기화 Job과 백업

초기화 Job은 완료 후 재실행되지 않습니다. 스키마를 변경하거나 DB 권한을 다시 설정할 때는 Job 버전을 변경하거나 로컬 Job을 명시적으로 재생성합니다. 기존 DB 계정 비밀번호는 Secret 수정만으로 바뀌지 않습니다.

백업 CronJob은 suspend:true로 제공하며 수동 Job으로 동작을 확인합니다. 백업 PVC는 클러스터 안에 있으므로 클러스터 외부 보관은 backup-restore.sh로 수행합니다. 이 스크립트는 원본을 덮어쓰지 않고 새 DB로 복원해 행 수를 비교합니다. 복구 중 쓰기 요청은 멈춘 상태에서 실습합니다.

## 목차와 집필 분량

서문 4쪽 + 본문 184쪽 + 부록 12쪽 = **200쪽**입니다.

### 1장. korora의 목표와 전체 구조 — 8쪽

[실습 안내와 명령](chapters/01-overview/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 1-1 | 측정 데이터가 저장되고 조회되기까지 | 클라이언트부터 진입점, 프록시, API, DB까지 전체 흐름을 읽고 쓰기와 조회를 다른 색으로 표시합니다. |
| 1-2 | 서비스를 나누는 기준과 각 구성 요소의 책임 | HTTP 서버·리버스 프록시·API·DB의 역할과 상태를 가진 구성 요소를 구분합니다. |
| 1-3 | korora의 데이터와 API 계약 정하기 | 측정 데이터와 쓰기·조회 요청을 작성하고 경로·메서드·필수 필드·응답을 정합니다. |
| 1-4 | 정상 요청의 흐름을 따라가 보기 | 한 건을 저장하고 다시 조회하는 순서도와 각 단계에서 관찰할 결과를 작성합니다. |
| 1-5 | 구조도에서 연결 하나를 지워 보기 | DB 연결이나 조회 경로가 빠진 그림에서 실패하는 기능과 이유를 설명합니다. |
| 1-6 | korora의 범위와 설계 원칙 기록하기 | 읽기·쓰기 API는 독립 배포하고 DB는 공유합니다. 공유 DB 장애의 영향도 기록합니다. |

### 2장. 재현 가능한 로컬 실습 환경 만들기 — 10쪽

[실습 안내와 명령](chapters/02-local-cluster/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 2-1 | 내 컴퓨터와 Kubernetes 클러스터의 관계 | 호스트·컨테이너 런타임·k3d 노드·Pod·외부 접속 포트를 연결합니다. |
| 2-2 | Node·Context·Namespace 이해하기 | kubeconfig·Context·Namespace와 노드·Pod의 차이를 배웁니다. |
| 2-3 | k3d 클러스터와 korora Namespace 생성하기 | 버전을 고정한 클러스터를 만들고 Traefik·StorageClass·네트워크 정책 구성을 확인합니다. |
| 2-4 | 실습 준비 상태 확인하기 | 노드 Ready 상태, 시스템 Pod, Namespace와 kubectl 연결을 확인합니다. |
| 2-5 | 접속 포트와 Namespace를 잘못 지정해 보기 | API 서버 접속 실패와 리소스를 찾지 못하는 상황을 구분하고 복구합니다. |
| 2-6 | korora의 실습 환경 기준 정하기 | 도구 버전·클러스터 이름·도메인·포트·디렉터리 구조를 정리합니다. |

### 3장. Nginx와 echo-server 배포하기 — 10쪽

[실습 안내와 명령](chapters/03-first-http/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 3-1 | Deployment가 Pod를 유지하는 구조 | Deployment → ReplicaSet → Pod 관리 관계와 HTTP 서버를 그립니다. |
| 3-2 | 이미지·Pod·ReplicaSet·Deployment 이해하기 | 선언적 설정·복제본 수·label·selector·이미지 버전 고정을 배웁니다. |
| 3-3 | 두 종류의 HTTP 서버 배포하기 | Nginx와 echo-server를 배포하고 port-forward로 접속해 로그를 확인합니다. |
| 3-4 | Pod 삭제 후 자동 복구 확인하기 | Pod 삭제 후 새 Pod가 생성되고 복제본 수가 유지되는지 확인합니다. |
| 3-5 | 존재하지 않는 이미지 태그 사용하기 | ImagePullBackOff를 발생시키고 상태·이벤트·설정에서 원인을 찾습니다. |
| 3-6 | korora의 무상태 서버 운영 방식 정하기 | 서버를 Deployment로 관리하는 이유와 영속 데이터를 분리하는 원칙을 정합니다. |

### 4장. Service와 DNS로 서버 연결하기 — 10쪽

[실습 안내와 명령](chapters/04-services-dns/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 4-1 | Service가 Pod를 찾아 연결하는 구조 | 클라이언트·Service DNS·ClusterIP·EndpointSlice·대상 Pod를 연결합니다. |
| 4-2 | Service 종류와 포트의 관계 이해하기 | ClusterIP·NodePort·Headless Service와 port·targetPort를 비교합니다. |
| 4-3 | Service 이름으로 여러 Pod에 접속하기 | echo-server 복제본을 늘리고 진단용 Pod에서 DNS로 요청하며 EndpointSlice를 관찰합니다. |
| 4-4 | Pod가 교체되어도 연결이 유지되는지 확인하기 | Pod 교체 전후 IP와 Service 주소를 비교하고 내부 DNS를 확인합니다. |
| 4-5 | selector와 targetPort를 각각 틀려 보기 | 대상 Pod가 없는 경우와 포트 연결만 실패하는 경우를 구분합니다. |
| 4-6 | korora의 내부 주소와 Service 이름 정하기 | 구성 요소의 이름과 포트를 정하고 Pod IP를 직접 설정하지 않도록 합니다. |

### 5장. ConfigMap과 Secret으로 설정 분리하기 — 10쪽

[실습 안내와 명령](chapters/05-configuration/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 5-1 | 설정이 컨테이너에 전달되는 두 가지 경로 | 환경변수 주입과 파일 마운트, ConfigMap·Secret 연결 위치를 그립니다. |
| 5-2 | 설정값·비밀값·이미지의 경계 정하기 | 각 오브젝트의 용도, 볼륨 마운트, Base64 표현과 암호화의 차이를 배웁니다. |
| 5-3 | Nginx 설정과 korora 안내 페이지 외부화하기 | ConfigMap으로 Nginx 설정·HTML을 제공하고 예제 Secret 마운트를 확인합니다. |
| 5-4 | 설정 변경이 반영되는 시점 확인하기 | 환경변수·마운트 파일·프로세스 재로딩의 차이와 생성된 설정 이름을 확인합니다. |
| 5-5 | Secret 키와 ConfigMap 참조를 틀려 보기 | 존재하지 않는 키나 리소스를 참조해 컨테이너 시작 실패를 조사합니다. |
| 5-6 | korora의 설정 항목 분류하기 | 일반 설정은 ConfigMap, DB 비밀번호·TLS 개인 키는 Secret으로 분류합니다. |

### 6장. Ingress와 TLS로 외부 요청 받기 — 14쪽

[실습 안내와 명령](chapters/06-ingress-tls/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 6-1 | 도메인에서 내부 Service까지의 진입 경로 | 이름 해석·호스트 포트·Controller·Service·Pod와 TLS 종료 지점을 표시합니다. |
| 6-2 | DNS·Ingress·Controller·TLS 이해하기 | Ingress와 Controller의 역할, Host·경로·인증서·SNI를 배웁니다. |
| 6-3 | korora.test를 HTTPS로 연결하기 | Traefik Ingress와 로컬 인증서를 연결하고 HTTP·HTTPS를 비교합니다. |
| 6-4 | Host 라우팅과 인증서 확인하기 | 안내 페이지, 인증서 이름과 TLS 종료 위치를 검사합니다. |
| 6-5 | Host·인증서·백엔드 이름을 틀려 보기 | 라우팅 실패·인증서 이름 불일치·잘못된 Service 참조를 조사합니다. |
| 6-6 | korora의 외부 접속 규칙 정하기 | 공개 도메인·경로·HTTP 처리 정책·인증서 갱신 책임을 정리합니다. |

### 7장. Envoy로 요청 경로 제어하기 — 12쪽

[실습 안내와 명령](chapters/07-envoy-routing/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 7-1 | Ingress와 애플리케이션 사이에 Envoy 배치하기 | Envoy Service·Pod 추가 전후의 요청 흐름을 비교합니다. |
| 7-2 | Listener·Route·Cluster 이해하기 | 요청 수신 지점·전달 규칙·업스트림·타임아웃의 관계를 배웁니다. |
| 7-3 | 경로에 따라 Nginx와 echo-server로 전달하기 | Envoy ConfigMap을 제공하고 안내·진단·쓰기·조회 경로를 나눕니다. |
| 7-4 | 어느 업스트림이 응답했는지 확인하기 | 응답과 접근 로그에서 경로·업스트림·재작성된 경로를 확인합니다. |
| 7-5 | Cluster 이름과 업스트림 주소를 틀려 보기 | 설정 오류와 연결 실패를 구분하고 설정 검증·로그·응답을 조사합니다. |
| 7-6 | korora의 라우팅 표 작성하기 | 경로 우선순위·상태 확인 예외·접두어 제거 규칙을 정합니다. |

### 8장. HTTP 헤더 검사와 전달 규칙 만들기 — 12쪽

[실습 안내와 명령](chapters/08-http-headers/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 8-1 | 프록시를 거치며 헤더가 바뀌는 과정 | 클라이언트 헤더와 프록시가 추가·수정하는 헤더를 구분합니다. |
| 8-2 | 헤더 필터링과 인증·인가의 관계 이해하기 | 형식 검사와 신원 검증의 차이, Host·전달 헤더의 역할을 배웁니다. |
| 8-3 | 요청을 검사하고 추적 헤더 추가하기 | X-Korora-Client 조건과 내부 헤더 덮어쓰기를 구성합니다. |
| 8-4 | 허용·거절·헤더 변경 결과 확인하기 | 정상·누락·잘못된 값의 응답과 echo-server가 받은 값을 비교합니다. |
| 8-5 | 클라이언트가 내부 헤더를 위조해 보기 | 내부 헤더를 직접 보내고 덮어쓰기 규칙과 프록시 신뢰 범위를 점검합니다. |
| 8-6 | korora의 요청 헤더 정책 작성하기 | 필수 헤더·프록시 신뢰 범위·민감 로그 제외·실제 인증 필요 지점을 정리합니다. |

### 9장. 미러링으로 같은 요청을 다른 서버에 보내기 — 12쪽

[실습 안내와 명령](chapters/09-mirroring/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 9-1 | 주 요청과 미러 요청이 갈라지는 구조 | 주 서버·Shadow로 분기되는 요청과 실제 응답 경로를 구분합니다. |
| 9-2 | 미러링과 응답 트래픽 분배 이해하기 | 복제 비율과 주 응답 선택 비율, Shadow 응답이 사용되지 않는 동작을 배웁니다. |
| 9-3 | 두 echo-server로 미러링 실습하기 | 서버 식별자를 구분하고 헤더·경로·본문의 전달을 관찰합니다. |
| 9-4 | 요청 수와 주 응답 출처 비교하기 | 충분한 요청 표본으로 복제 비율과 실제 주 응답을 비교합니다. |
| 9-5 | Shadow 서버를 중단하거나 느리게 만들기 | 제공된 중단 시나리오로 주 응답·프록시 로그·오류 지표를 관찰합니다. 지연 주입은 확장 과제로 둡니다. |
| 9-6 | korora의 미러링 대상과 제외 경로 정하기 | DB 연결 이후 조회 경로만 복제하고 쓰기·상태 확인 경로는 제외합니다. |

### 10장. PostgreSQL과 영속 스토리지 구성하기 — 12쪽

[실습 안내와 명령](chapters/10-postgres-storage/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 10-1 | DB Pod와 영속 볼륨의 연결 구조 | PostgreSQL·Service·StatefulSet·PVC·PV·StorageClass를 연결합니다. |
| 10-2 | StatefulSet과 스토리지 수명 이해하기 | Pod 식별자·동적 프로비저닝·접근 모드·회수 정책을 배웁니다. |
| 10-3 | Secret과 PVC를 사용해 PostgreSQL 배포하기 | DB를 배포하고 SQL로 저장합니다. 클라이언트 Service와 Headless Service를 구분합니다. |
| 10-4 | DB Pod 재생성 후 데이터 확인하기 | Pod 교체 전후 데이터·PVC를 확인하고 Pod·볼륨·클러스터 수명을 구분합니다. |
| 10-5 | 잘못된 StorageClass와 접속 정보 사용하기 | PVC Pending과 DB 인증 실패를 각각 조사합니다. 기존 볼륨을 지우지 않고 별도 예제로 실습합니다. |
| 10-6 | korora의 데이터 보존 범위 정하기 | 단일 DB 한계·로컬 볼륨 보존 범위·백업 대상·복구 기준을 기록합니다. |

### 11장. 데이터를 저장하는 Ingest API 만들기 — 12쪽

[실습 안내와 명령](chapters/11-ingest-api/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 11-1 | HTTP 쓰기 요청에서 INSERT까지의 흐름 | Envoy → Ingest → PostgREST → PostgreSQL 경로와 권한 경계를 표시합니다. |
| 11-2 | PostgREST·DB Role·Job 이해하기 | 테이블 API·DB 권한·초기화 Job과 반복 실행 시 고려할 점을 배웁니다. |
| 11-3 | 스키마와 쓰기 전용 API 구성하기 | Job으로 테이블·권한을 만들고 PostgREST를 배포해 JSON 데이터를 저장합니다. |
| 11-4 | HTTP 응답과 DB 저장 결과 대조하기 | 성공 응답·실제 행·필수 필드 누락·자료형 오류·중복 이벤트를 확인합니다. |
| 11-5 | INSERT 권한과 이벤트 식별자를 깨뜨려 보기 | 권한 제거·잘못된 접속 정보·중복 event_id로 실패 원인을 확인합니다. |
| 11-6 | korora의 쓰기 계약과 재시도 규칙 정하기 | 허용 메서드·입력 제약·중복 처리·재시도 영향을 정리합니다. |

### 12장. 데이터를 읽는 Query API 만들기 — 10쪽

[실습 안내와 명령](chapters/12-query-api/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 12-1 | 저장된 데이터가 조회 응답으로 돌아오는 흐름 | 조회 경로와 쓰기 API가 공유하는 DB를 표시합니다. |
| 12-2 | 읽기 전용 권한과 조회 조건 이해하기 | 필터·정렬·결과 제한·페이지 처리·빈 결과와 오류를 구분합니다. |
| 12-3 | 읽기 전용 PostgREST 배포하기 | 별도 DB 권한으로 Query API를 배포하고 장비·메트릭·시간 조건으로 조회합니다. |
| 12-4 | 쓰기부터 조회까지 한 번에 확인하기 | 저장 데이터와 조회 결과를 대조하고 읽기 API의 쓰기 거절을 확인합니다. |
| 12-5 | 조회 권한과 필터 조건을 틀려 보기 | 권한 오류·잘못된 문법·정상적인 빈 결과·스키마 오류를 구분합니다. |
| 12-6 | korora의 조회 인터페이스 정리하기 | 기본 정렬·최대 조회량·허용 메서드·미러링 규칙을 확정합니다. |

### 13장. 상태 검사와 롤링 업데이트로 서비스 유지하기 — 12쪽

[실습 안내와 명령](chapters/13-reliability/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 13-1 | Pod 상태와 트래픽 대상의 관계 | Probe·Ready·Service Endpoint·종료 중 Pod의 관계를 그립니다. |
| 13-2 | Probe·리소스·업데이트 전략 이해하기 | startup·readiness·liveness·requests·limits·RollingUpdate·종료 유예·PDB를 배웁니다. |
| 13-3 | 상태 검사를 추가하고 요청 중 업데이트하기 | 복제본과 Probe를 구성하고 연속 요청 중 설정 변경·롤아웃을 진행합니다. |
| 13-4 | 요청 성공률과 Pod 교체 과정 확인하기 | Ready·Endpoint 변경 시점과 요청 실패 여부를 관찰합니다. |
| 13-5 | 상태 검사 경로와 리소스 요청을 틀려 보기 | 재시작 반복과 스케줄링 Pending을 구분하고 복구합니다. |
| 13-6 | korora 구성 요소별 운영 기준 정하기 | 상태 검사·종료 정책을 정하고 외부 의존성 장애와 프로세스 장애를 구분합니다. |

### 14장. 로그와 메트릭으로 장애 원인 찾기 — 10쪽

[실습 안내와 명령](chapters/14-observability/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 14-1 | 요청과 관측 데이터가 흐르는 구조 | 프록시 로그·API 로그·DB 오류·Envoy 메트릭의 발생 지점을 표시합니다. |
| 14-2 | 접근 로그·요청 ID·메트릭 이해하기 | HTTP 상태·업스트림 오류·지연·요청 수·오류율·민감 정보 기록을 다룹니다. |
| 14-3 | 요청 하나를 여러 로그에서 추적하기 | 요청 ID를 전달하고 로그를 비교하며 Prometheus로 Envoy 지표를 수집합니다. |
| 14-4 | 정상 요청과 실패 요청의 증거 비교하기 | 카운터 변화와 오류 로그·지표의 상관관계를 확인합니다. |
| 14-5 | 업스트림 연결 실패를 단계별로 조사하기 | DNS → Service → Endpoint → 포트 → 애플리케이션 → DB 순서로 좁혀 갑니다. |
| 14-6 | korora의 기본 관측 항목 정하기 | 최소 로그·핵심 지표·오류 증가 시 진단 절차를 작성합니다. |

### 15장. 최소 권한과 NetworkPolicy 적용하기 — 12쪽

[실습 안내와 명령](chapters/15-access-control/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 15-1 | 외부 요청·내부 통신·관리 권한의 경계 | 사용자 요청·Pod 통신·Kubernetes API 접근·DB 권한을 구분합니다. |
| 15-2 | ServiceAccount·RBAC·NetworkPolicy 이해하기 | Role·RoleBinding·서비스 계정·정책 선택과 허용·DNS 예외를 배웁니다. |
| 15-3 | korora에 필요한 접근만 허용하기 | 조회 Role과 서비스 계정을 만들고 DB 통신·프록시 통신을 제한합니다. |
| 15-4 | 허용·차단 결과를 실제로 확인하기 | 권한별 리소스 조회와 Pod 간 연결을 비교해 정책 강제 여부를 확인합니다. |
| 15-5 | DNS와 DB 접근을 실수로 차단해 보기 | 이름 해석 실패와 DB 연결 실패를 구분하고 빠진 허용 규칙을 복구합니다. |
| 15-6 | korora의 접근 제어 표 완성하기 | 주체·리소스·권한과 Pod·목적지·포트를 표로 정리합니다. |

### 16장. Kustomize로 묶고 korora 완성하기 — 18쪽

[실습 안내와 명령](chapters/16-packaging/README.md)

| 절 | 세부 챕터 제목 | 주요 내용과 실습 |
| --- | --- | --- |
| 16-1 | 완성된 서비스와 배포 파일의 관계 | 최종 요청 흐름과 오브젝트 관리 관계를 각각 그립니다. |
| 16-2 | base·overlay와 설정 변경의 영향 이해하기 | 리소스 조합·patch·ConfigMap/Secret 생성·이름 참조·롤아웃을 배웁니다. |
| 16-3 | korora 배포 패키지와 복구 절차 만들기 | 기본·미러링 overlay를 나누고 CronJob을 수동 실행하며 외부 백업과 별도 DB 복구를 실습합니다. |
| 16-4 | 처음부터 배포하고 완료 조건 검증하기 | 새 환경에서 안내·쓰기·조회·필터·미러링·영속성·정책·복구를 확인합니다. |
| 16-5 | 설정 오류가 들어간 배포본 복구하기 | 잘못된 참조를 하나씩 주입하고 렌더링·이벤트·로그로 진단해 복구합니다. |
| 16-6 | korora의 설계 문서와 운영 절차 작성하기 | 구조도·설정표·권한표·장애 대응·백업/복구·제약·개선 과제를 정리합니다. |

## 서문과 부록

| 구성 | 내용 | 분량 |
| --- | --- | --- |
| 서문 | 이름의 유래·학습 목표·선수 지식·진행 방법 | 4쪽 |
| 부록 A | 도구·이미지 버전·디렉터리·환경 재생성 | 4쪽 |
| 부록 B | kubectl·curl·SQL과 증상별 진단 순서 | 4쪽 |
| 부록 C | 완료 체크리스트·용어·리소스 정리 | 4쪽 |

## 교재에서 확인할 핵심 구분

- 네트워크 요청 흐름과 Deployment·StatefulSet의 관리 관계
- Ingress 리소스와 요청을 실제로 처리하는 Controller
- 헤더 형식 검사와 사용자 인증·인가
- 미러링 비율과 주 응답 선택 비율
- 프로세스 생존과 요청 처리 준비 상태
- Service DNS·Endpoint·애플리케이션 포트의 관계
- Pod 교체에 대한 영속성과 클러스터 외부 백업
- DB 권한과 Kubernetes RBAC·NetworkPolicy
- 공유 DB를 사용하는 단순화의 이점과 장애 영향

## 참고 도서

- Elton Stoneman, [Learn Kubernetes in a Month of Lunches](https://www.manning.com/books/learn-kubernetes-in-a-month-of-lunches), 국내 번역서 《쿠버네티스 교과서》: 장별 실습의 진행 방식과 입문자 설명 수준 참고.
- Marko Lukša, Kevin Conner, [Kubernetes in Action, Second Edition](https://www.manning.com/books/kubernetes-in-action-second-edition): 네트워크·설정·스토리지·운영 개념의 심화 참고.

## 정리와 재시작

port-forward 프로세스는 해당 터미널에서 종료합니다. 진단 Pod·별도 Pending PVC·수동 백업 Job은 실습 뒤 개별 정리합니다. DB 복구본은 원본과 별개로 남으므로 확인 후 정리합니다. 클러스터를 삭제하면 로컬 DB와 백업 PVC 데이터가 사라질 수 있으므로 먼저 클러스터 밖 백업을 확인합니다.

전용 로컬 클러스터를 처음부터 다시 만들 때만 다음 명령을 사용합니다.

~~~sh
k3d cluster delete korora
# 전용 진행 기록만 초기화합니다. .local/backups는 보존합니다.
rm -f .local/current-chapter .local/kubeconfig
./scripts/setup.sh
~~~

실제 요청을 받을 준비가 된 뒤 Service 대상으로 포함되도록 Envoy와 PostgREST에는 기본 readiness를 먼저 제공합니다. 13장에서 startup·liveness와의 차이 및 업데이트 정책을 확장해 학습합니다.
