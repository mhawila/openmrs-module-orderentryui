angular.module('drugOrders', ['orderService', 'encounterService', 'encounterRoleService', 'uicommons.filters',
    'uicommons.widget.select-concept-from-list', 'uicommons.widget.select-order-frequency',
    'uicommons.widget.select-drug', 'session', 'orderEntry', 'ui.select']).

    config(function($locationProvider) {
        $locationProvider.html5Mode({
            enabled: true,
            requireBase: false
        });
    }).

    filter('dates', ['serverDateFilter', function(serverDateFilter) {
        return function(order) {
            if (!order || typeof order != 'object') {
                return "";
            }
            if (order.action === 'DISCONTINUE' || !order.dateActivated) {
                return "";
            } else {
                var text = serverDateFilter(order.dateActivated);
                if (order.dateStopped) {
                    text += ' - ' + serverDateFilter(order.dateStopped);
                }
                else if (order.autoExpireDate) {
                    text += ' - ' + serverDateFilter(order.autoExpireDate);
                }
                return text;
            }
        }
    }]).

    filter('instructions', function() {
        return function(order) {
            if (!order || typeof order != 'object') {
                return "";
            }
            if (order.action == 'DISCONTINUE') {
                var drug = '';
                if(order.drug && typeof order.drug === 'object') {
                    drug = order.drug.display;
                }
                else if(order.drugNonCoded) {
                    drug = order.drugNonCoded + ' (non coded)';
                }
                else if(order.concept) {
                    drug = order.concept.display;
                }

                return "Discontinue: " + drug;
            }
            else {
                var text = order.getDosingType().format(order);
                if (order.quantity) {
                    text += ' (Dispense: ' + order.quantity + ' ' + order.quantityUnits.display + ')';
                }
                return text;
            }
        }
    }).

    filter('replacement', ['serverDateFilter', function(serverDateFilter) {
        // given the order that replaced the one we are displaying, display the details of the replacement
        return function(replacementOrder) {
            if (!replacementOrder) {
                return "";
            }
            return emr.message("orderentryui.pastAction." + replacementOrder.action) + ", " + serverDateFilter(replacementOrder.dateActivated);
        }
    }]).

    controller('DrugOrdersCtrl', ['$scope', '$window', '$location', '$timeout', 'OrderService', 'EncounterService',
        'EncounterRoleService', 'SessionInfo', 'OrderEntryService', '$sce', function($scope, $window, $location, $timeout,
                         OrderService, EncounterService, EncounterRoleService, SessionInfo, OrderEntryService, $sce) {
            $scope.encounterRole = {
                selected: undefined,
            };
            var orderContext = {};
            SessionInfo.get().$promise.then(function(info) {
                orderContext.provider = info.currentProvider;
                $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftDrugOrder(orderContext);
            });

            $scope.dateActivatedPicker = {
                opened: false,
                options: {
                    dateDisabled: function (data) {
                        var date = data.date,
                            mode = data.mode;
                        return mode === 'day' && (date.getDay() === 0 || date.getDay() === 6);
                    },
                    formatYear: 'yy',
                    startingDay: 1,
                    showWeeks: false,
                    datepickerMode: 'month',
                    maxDate: (new Date()).getTime(),
                },
                open: function($event) {
                    $event.preventDefault();
                    $event.stopPropagation();
                    $scope.dateActivatedPicker.opened = true;
                },
                altInputFormats: ['d!/M!/yyyy']
            };

            // TODO changing dosingType of a draft order should reset defaults (and discard non-defaulted properties)

            function loadExistingOrders() {
                $scope.activeDrugOrders = { loading: true };
                OrderService.getOrders({
                    t: 'drugorder',
                    v: 'full',
                    patient: config.patient.uuid,
                    careSetting: $scope.careSetting.uuid
                }).then(function(results) {
                    $scope.activeDrugOrders = _.map(results, function(item) { return new OpenMRS.DrugOrderModel(item) });
                });

                $scope.pastDrugOrders = { loading: true };
                OrderService.getOrders({
                    t: 'drugorder',
                    v: 'full',
                    patient: config.patient.uuid,
                    careSetting: $scope.careSetting.uuid,
                    status: 'inactive'
                }).then(function(results) {
                    $scope.pastDrugOrders = _.map(results, function(item) { return new OpenMRS.DrugOrderModel(item) });
                });
            }


            function replaceWithUuids(obj, props) {
                var replaced = angular.extend({}, obj);
                _.each(props, function(prop) {
                    if (replaced[prop] && replaced[prop].uuid) {
                        replaced[prop] = replaced[prop].uuid;
                    }
                });
                return replaced;
            }

            $scope.loading = false;

            $scope.activeDrugOrders = { loading: true };
            $scope.pastDrugOrders = { loading: true };
            $scope.draftDrugOrders = [];
            $scope.dosingTypes = OpenMRS.dosingTypes;

            var config = OpenMRS.drugOrdersConfig;
            $scope.init = function() {
                $scope.routes = config.routes;
                $scope.doseUnits = config.doseUnits;
                $scope.durationUnits = config.durationUnits;
                $scope.quantityUnits = config.quantityUnits;
                $scope.frequencies = config.frequencies;
                $scope.careSettings = config.careSettings;
                $scope.careSetting = config.intialCareSetting ?
                    _.findWhere(config.careSettings, { uuid: config.intialCareSetting }) :
                    config.careSettings[0];

                orderContext.careSetting = $scope.careSetting;

                loadExistingOrders();

                $timeout(function() {
                    angular.element('#new-order input[type=text]').first().focus();
                });
            }


            // functions that affect the overall state of the page

            $scope.setCareSetting = function(careSetting) {
                // TODO confirm dialog or undo functionality if this is going to discard things
                $scope.careSetting = careSetting;
                orderContext.careSetting = $scope.careSetting;
                loadExistingOrders();
                $scope.draftDrugOrders = [];
                $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftDrugOrder(orderContext);
                $location.search({ patient: config.patient.uuid, careSetting: careSetting.uuid });
            }

            // functions that affect the new order being written

            $scope.addNewDraftOrder = function() {
                // Set quantity & units
                if($scope.newDraftDrugOrder.dosingType !== 'org.openmrs.FreeTextDosingInstructions') {
                    $scope.newDraftDrugOrder.quantity = $scope.newDraftDrugOrder.dose * $scope.newDraftDrugOrder.duration;
                    $scope.newDraftDrugOrder.quantityUnits = $scope.newDraftDrugOrder.doseUnits;
                }
                console.log($scope.newDraftDrugOrder);
                if ($scope.newDraftDrugOrder.getDosingType().validate($scope.newDraftDrugOrder)) {
                    $scope.newDraftDrugOrder.asNeeded = $scope.newDraftDrugOrder.asNeededCondition ? true : false;
                    $scope.draftDrugOrders.push($scope.newDraftDrugOrder);
                    $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftDrugOrder(orderContext);
                    $scope.newOrderForm.$setPristine();
                    // TODO upgrade to angular 1.3 and work on form validation
                    $scope.newOrderForm.$setUntouched();
                } else {
                    emr.errorMessage("Invalid");
                }
            }

            $scope.cancelNewDraftOrder = function() {
                $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftDrugOrder(orderContext);
            }


            // functions that affect the shopping cart of orders written but not yet saved

            $scope.cancelAllDraftDrugOrders = function() {
                $scope.draftDrugOrders = [];
            }

            $scope.cancelDraftDrugOrder = function(draftDrugOrder) {
                $scope.draftDrugOrders = _.without($scope.draftDrugOrders, draftDrugOrder);
            }

            $scope.editDraftDrugOrder = function(draftDrugOrder) {
                $scope.draftDrugOrders = _.without($scope.draftDrugOrders, draftDrugOrder);
                $scope.newDraftDrugOrder = draftDrugOrder;
            }

            /**
             * Finds the replacement order for a given active order (e.g. the order that will DC or REVISE it)
             */
            $scope.replacementFor = function(activeOrder) {
                var lookAt = $scope.newDraftDrugOrder ?
                    _.union($scope.draftDrugOrders, [$scope.newDraftDrugOrder]) :
                    $scope.draftDrugOrders;
                return _.findWhere(lookAt, { previousOrder: activeOrder });
            }

            $scope.replacementForPastOrder = function(pastOrder) {
                var candidates = _.union($scope.activeDrugOrders, $scope.pastDrugOrders)
                return _.find(candidates, function(item) {
                    return item.previousOrder && item.previousOrder.uuid === pastOrder.uuid;
                });
            }

            $scope.signAndSaveDraftDrugOrders = function() {
                var encounterContext = {
                    patient: config.patient,
                    encounterType: config.drugOrderEncounterType,
                    encounterRole: $scope.encounterRole.selected,
                    location: null, // TODO
                    visit: config.visit
                };

                $scope.loading = true;
                OrderEntryService.signAndSave({ draftOrders: $scope.draftDrugOrders }, encounterContext)
                    .$promise.then(function(result) {
                        location.href = location.href;
                    }, function(errorResponse) {
                        emr.errorMessage(errorResponse.data.error.message);
                        $scope.loading = false;
                    });
            }


            // functions that affect existing active orders

            $scope.discontinueOrder = function(activeOrder) {
                var dcOrder = activeOrder.createDiscontinueOrder(orderContext);
                $scope.draftDrugOrders.push(dcOrder);
                $scope.$broadcast('added-dc-order', dcOrder);
            }

            $scope.reviseOrder = function(activeOrder) {
                $scope.newDraftDrugOrder = activeOrder.createRevisionOrder();
            }

            $scope.encounterRoles = [];
            $scope.encounterRole.loading = true;
            (function() {
                EncounterRoleService.getEncounterRoles().then(function(roles) {
                    $scope.encounterRoles = roles.map(function(role) {
                        role.trustedDisplay = $sce.trustAsHtml(role.display);
                        return role;
                    });
                    $scope.encounterRole.loading = false;
                });
            })();

            // events

            $scope.$on('added-dc-order', function(dcOrder) {
                $timeout(function() {
                    angular.element('#draft-orders input.dc-reason').last().focus();
                });
            })

        }]);