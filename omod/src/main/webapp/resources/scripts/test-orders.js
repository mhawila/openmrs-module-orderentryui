angular.module('testOrders', ['orderService', 'encounterService', 'encounterRoleService', 'uicommons.filters',
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

    filter('instructions', function($filter) {
        return function(order) {
            if (!order || typeof order != 'object') {
                return "";
            }
            if (order.action == 'DISCONTINUE') {
                if(order.type == 'drugorder') {
                    return "Discontinue " + (order.drug ? order.drug : order.concept ).display;
                }
                if(order.type == 'testorder') {
                    return "Discontinue" + (order.concept.conceptName ? order.concept.conceptName.name
                                                                                        : order.concept.display);
                }
            }
            else {
                if(order.type == 'drugorder') {
                    var text = order.getDosingType().format(order);
                    if (order.quantity) {
                        text += ' (Dispense: ' + order.quantity + ' ' + order.quantityUnits.display + ')';
                    }
                    return text;
                }
                if(order.type == 'testorder') {
                    var text = order.concept.conceptName ? order.concept.conceptName.name : order.concept.display;
                    if(angular.isDefined(order.scheduledDate)) {
                        text += ", scheduled on " + $filter('date')(order.scheduledDate, 'dd/MMM/yyyy');
                    }
                    if(angular.isDefined(order.specimen)) {
                        test += ", specime: " + specimen.display;
                    }
                    return text;
                }
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

    controller('TestOrdersCtrl', ['$scope', '$window', '$location', '$timeout', 'OrderService', 'EncounterService',
        'EncounterRoleService', 'SessionInfo', 'OrderEntryService', '$sce', '$filter', function($scope, $window,
        $location, $timeout, OrderService, EncounterService, EncounterRoleService, SessionInfo, OrderEntryService,
        $sce, $filter) {
            $scope.encounterRole = {
                selected: undefined,
            };

            $scope.scheduledDatepicker = {
                opened: false,
                options: {
                    dateDisabled: function (data) {
                        var date = data.date,
                            mode = data.mode;
                        return mode === 'day' && (date.getDay() === 0 || date.getDay() === 6);
                    },
                    formatYear: 'yy',
                    minDate: $filter('date')(new Date(), 'YYYY-MM-dd'),
                    startingDay: 1,
                    showWeeks: false,
                    datepickerMode: 'month',
                },
                open: function($event) {
                    $event.preventDefault();
                    $event.stopPropagation();
                    $scope.scheduledDatepicker.opened = true;
                },
                altInputFormats: ['d!/M!/yyyy']
            };

            var orderContext = {};
            SessionInfo.get().$promise.then(function(info) {
                orderContext.provider = info.currentProvider;
                $scope.newDraftTestOrder = OpenMRS.createEmptyDraftTestOrder(orderContext);
            });


            function loadExistingOrders() {
                $scope.activeTestOrders = { loading: true };
                OrderService.getOrders({
                    t: 'testorder',
                    v: 'full',
                    patient: config.patient.uuid,
                    careSetting: $scope.careSetting.uuid
                }).then(function(results) {
                    $scope.activeTestOrders = _.map(results, function(item) { return new OpenMRS.TestOrderModel(item) });
                });

                $scope.pastTestOrders = { loading: true };
                OrderService.getOrders({
                    t: 'testorder',
                    v: 'full',
                    patient: config.patient.uuid,
                    careSetting: $scope.careSetting.uuid,
                    status: 'inactive'
                }).then(function(results) {
                    $scope.pastTestOrders = _.map(results, function(item) { return new OpenMRS.TestOrderModel(item) });
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

            $scope.activeTestOrders = { loading: true };
            $scope.pastTestOrders = { loading: true };
            $scope.draftTestOrders = [];

            var config = OpenMRS.testOrdersConfig;
            $scope.init = function() {
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


            // functions that affect the new order being written

            $scope.addNewDraftOrder = function() {
                if($scope.newDraftTestOrder.concept.conceptName) {
                    $scope.newDraftTestOrder.concept.display = $scope.newDraftTestOrder.concept.conceptName.name;
                }
                $scope.draftTestOrders.push($scope.newDraftTestOrder);
                $scope.newDraftTestOrder = OpenMRS.createEmptyDraftTestOrder(orderContext);
                $scope.newOrderForm.$setPristine();
                $scope.newOrderForm.$setUntouched();
            }

            $scope.cancelNewDraftOrder = function() {
                $scope.newDraftTestOrder = OpenMRS.createEmptyDraftTestOrder(orderContext);
            }


            // functions that affect the shopping cart of orders written but not yet saved

            $scope.cancelAllDraftTestOrders = function() {
                $scope.draftTestOrders = [];
            }

            $scope.cancelDraftTestOrder = function(draftTestOrder) {
                $scope.draftTestOrders = _.without($scope.draftTestOrders, draftTestOrder);
            }

            $scope.editDraftTestOrder = function(draftTestOrder) {
                $scope.draftTestOrders = _.without($scope.draftTestOrders, draftTestOrder);
                $scope.newDraftTestOrder = draftTestOrder;
            }

            /**
             * Finds the replacement order for a given active order (e.g. the order that will DC or REVISE it)
             */
            $scope.replacementFor = function(activeOrder) {
                var lookAt = $scope.newDraftTestOrder ?
                    _.union($scope.draftTestOrders, [$scope.newDraftTestOrder]) :
                    $scope.draftTestOrders;
                return _.findWhere(lookAt, { previousOrder: activeOrder });
            }

            $scope.replacementForPastOrder = function(pastOrder) {
                var candidates = _.union($scope.activeTestOrders, $scope.pastTestOrders)
                return _.find(candidates, function(item) {
                    return item.previousOrder && item.previousOrder.uuid === pastOrder.uuid;
                });
            }

            $scope.signAndSaveDraftTestOrders = function() {
                var encounterContext = {
                    patient: config.patient,
                    encounterType: config.orderEncounterType,
                    encounterRole: $scope.encounterRole.selected,
                    location: null, // TODO
                    visit: config.visit
                };

                // Replace concept with concept.
                var ordersToSave = _.map($scope.draftTestOrders, function (order) {
                    var obj = jQuery.extend({}, order);
                    if(order.concept.concept !== undefined) {
                        obj.concept = order.concept.concept;
                    }
                    return obj;
                });

                $scope.loading = true;
                OrderEntryService.signAndSave({ draftOrders: ordersToSave }, encounterContext)
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
                $scope.draftTestOrders.push(dcOrder);
                $scope.$broadcast('added-dc-order', dcOrder);
            }

            $scope.reviseOrder = function(activeOrder) {
                $scope.newDraftTestOrder = activeOrder.createRevisionOrder();
            }

            $scope.orderableConcepts = [];
            $scope.searchConcepts = function(search) {
                var params = search ? { term: search } : {};
                return OrderEntryService.getOrderableTests(params);
            }

            // Get the encounter roles required to associate the encounter with a provider
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