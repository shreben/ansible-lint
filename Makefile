
help: #help
	@echo "simply run the following command to get preconfigured sonar for ansible-lint:"
	@echo ""
	@echo "make run"
	@echo "or"
	@echo "make destroy"
	@echo "to burn everything down"
	@echo "------------------------------"

run: #run
	@echo "PHASE 1: ==== containers startup ===="
	docker-compose up -d
	@echo "PHASE 2: ==== configuration ===="
	./scripts/sonar-configuration.sh
	@echo "DONE"

destroy: #destroy
	@echo "Fire and forget" 
	docker-compose down -v --remove-orphans
