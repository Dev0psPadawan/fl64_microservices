USER_NAME = fl64
# Run `make VM_NAME=machinename` to override the default
VM_NAME = vm1
#dont forget set var. For example GOOGLE_PROJECT = docker-201818
GOOGLE_PROJECT = docker-201818
APP_TAG = logging

.PHONY: init init_vm init_fw
		destroy destroy_fw destroy_vm ip
		build build_ui build_comment build_post build_prometheus build_mongodb_exporter build_alert_manager build_fluentd
		build_mon build_log
		push push_ui push_comment push_post push_prometheus push_mongodb_exporter push_alert_manager push_fluentd
		app_start app_stop app_restart
		mon_start mon_stop mon_restart
		log_start log_stop log_restart
		start stop restart rebuild

### Docker machine section
init: init_fw init_vm
init_vm:
	export GOOGLE_PROJECT=$(GOOGLE_PROJECT) \
	&& docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --engine-opt experimental --engine-opt metrics-addr=0.0.0.0:9323 \
    $(VM_NAME)

init_fw:
	export GOOGLE_PROJECT=$(GOOGLE_PROJECT) \
	&& gcloud compute firewall-rules create prometheus-default --target-tags=docker-machine --allow tcp:9090 | true \
	&& gcloud compute firewall-rules create puma-default --target-tags=docker-machine --allow tcp:9292 | true \
	&& gcloud compute firewall-rules create cadviser-default --target-tags=docker-machine --allow tcp:8080 | true \
	&& gcloud compute firewall-rules create grafana-default --target-tags=docker-machine --allow tcp:3000 | true \
	&& gcloud compute firewall-rules create alert-manager-default --target-tags=docker-machine --allow tcp:9093 | true \
	&& gcloud compute firewall-rules create docker-mon-default --target-tags=docker-machine --allow tcp:9323 | true \
	&& gcloud compute firewall-rules create kibana-default --target-tags=docker-machine --allow tcp:5601 | true \
	&& gcloud compute firewall-rules create zipkin-default --target-tags=docker-machine --allow tcp:9411 | true


destroy: destroy_fw destroy_vm
destroy_fw:
	export GOOGLE_PROJECT=$(GOOGLE_PROJECT) \
	&& gcloud compute firewall-rules delete puma-default --quiet | true \
	&& gcloud compute firewall-rules delete prometheus-default --quiet | true \
	&& gcloud compute firewall-rules delete cadviser-default --quiet | true \
	&& gcloud compute firewall-rules delete grafana-default --quiet | true \
	&& gcloud compute firewall-rules delete alert-manager-default --quiet | true \
	&& gcloud compute firewall-rules delete docker-mon-default --quiet | true \
	&& gcloud compute firewall-rules delete kibana-default --quiet | true \
	&& gcloud compute firewall-rules delete zipkin-default --quiet | true

destroy_vm:
	export GOOGLE_PROJECT=$(GOOGLE_PROJECT) \
	&& docker-machine rm $(VM_NAME) -f
ip:
	docker-machine ip $(VM_NAME)

### Build section
build: build_ui build_comment build_post
build_ui:
	cd src/ui && bash docker_build.sh
build_comment:
	cd src/comment && bash docker_build.sh
build_post:
	cd src/post-py && bash docker_build.sh

build_mon: build_prometheus build_mongodb_exporter build_alert_manager
build_prometheus:
	docker build -t $(USER_NAME)/prometheus monitoring/prometheus
build_mongodb_exporter:
	docker build -t $(USER_NAME)/mongodb_exporter monitoring/mongodb_exporter
build_alert_manager:
	docker build -t $(USER_NAME)/alertmanager monitoring/alertmanager

build_log: build_fluentd
build_fluentd:
	docker build -t $(USER_NAME)/fluentd logging/fluentd

### Build bugged
build_bugged: build_bugged_ui build_bugged_comment build_bugged_post
build_bugged_ui:
	cd src/bugged-code-master/ui && bash docker_build.sh
build_bugged_comment:
	cd src/bugged-code-master/comment && bash docker_build.sh
build_bugged_post:
	cd src/bugged-code-master/post-py && bash docker_build.sh

### Push images section
push: push_ui push_comment push_post push_prometheus push_mongodb_exporter push_alert_manager push_fluentd
push_ui:
	docker push $(USER_NAME)/ui:$(APP_TAG)
push_comment:
	docker push $(USER_NAME)/comment:$(APP_TAG)
push_post:
	docker push $(USER_NAME)/post:$(APP_TAG)
push_prometheus:
	docker push $(USER_NAME)/prometheus
push_mongodb_exporter:
	docker push $(USER_NAME)/mongodb_exporter
push_alert_manager:
	docker push $(USER_NAME)/alertmanager
push_fluentd:
	docker push $(USER_NAME)/fluentd

### App section
app_start:
	cd docker; docker-compose up -d | true
app_stop:
	cd docker; docker-compose down | true
app_restart: app_stop app_start

### Monitoring section
mon_start:
	cd docker; docker-compose -f docker-compose-monitoring.yml up -d | true
mon_stop:
	cd docker; docker-compose -f docker-compose-monitoring.yml down | true
mon_restart: mon_stop mon_start

### Monitoring section
log_start:
	cd docker; docker-compose -f docker-compose-logging.yml up -d | true
log_stop:
	cd docker; docker-compose -f docker-compose-logging.yml down | true
log_restart: log_stop log_start


### App and mon section
start:
	cd docker && docker-compose -f docker-compose-logging.yml -f docker-compose-monitoring.yml -f docker-compose.yml up -d
stop:
	cd docker && docker-compose -f docker-compose-logging.yml -f docker-compose-monitoring.yml -f docker-compose.yml down
restart: stop start
rebuild: build push stop start

teststop:
	cd docker && docker-compose stop post
teststart:
	cd docker && docker-compose start post
