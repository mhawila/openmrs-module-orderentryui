<%
    ui.decorateWith("appui", "standardEmrPage")

    ui.includeJavascript("uicommons", "angular.min.js")
    ui.includeJavascript("uicommons", "angular-app.js")
    ui.includeJavascript("uicommons", "angular-resource.min.js")
    ui.includeJavascript("uicommons", "angular-common.js")
    ui.includeJavascript("uicommons", "angular-ui/ui-bootstrap-tpls-0.11.2.js")
    ui.includeJavascript("uicommons", "ngDialog/ngDialog.js")
    ui.includeJavascript("uicommons", "filters/display.js")
    ui.includeJavascript("uicommons", "filters/serverDate.js")
    ui.includeJavascript("uicommons", "services/conceptService.js")
    ui.includeJavascript("uicommons", "services/drugService.js")
    ui.includeJavascript("uicommons", "services/encounterService.js")
    ui.includeJavascript("uicommons", "services/encounterRoleService.js")
    ui.includeJavascript("uicommons", "services/orderService.js")
    ui.includeJavascript("uicommons", "services/session.js")
    ui.includeJavascript("uicommons", "directives/select-concept-from-list.js")
    ui.includeJavascript("uicommons", "directives/select-order-frequency.js")
    ui.includeJavascript("uicommons", "directives/select-drug.js")
    ui.includeJavascript("orderentryui", "order-model.js")
    ui.includeJavascript("orderentryui", "order-entry.js")
    ui.includeJavascript("orderentryui", "drug-orders.js")
    ui.includeJavascript("orderentryui", "select.min.js")

    ui.includeCss("uicommons", "ngDialog/ngDialog.min.css")
    ui.includeCss("orderentryui", "drugOrders.css")
    ui.includeCss("orderentryui", "select.min.css")
    ui.includeCss("orderentryui", "selectize.default.min.css")
%>
<script type="text/javascript" xmlns="http://www.w3.org/1999/html">
    var breadcrumbs = [
        { icon: "icon-home", link: '/' + OPENMRS_CONTEXT_PATH + '/index.htm' },
        { label: "${ ui.format(patient.familyName) }, ${ ui.format(patient.givenName) }" ,
            link: '${ui.pageLink("coreapps", "clinicianfacing/patient", [patientId: patient.id])}'},
        { label: "Drug Orders" }
    ]
    window.OpenMRS = window.OpenMRS || {};
    window.OpenMRS.drugOrdersConfig = ${ jsonConfig };
</script>
<style>
    .select2 > .select2-choice.ui-select-match {
        /* Because of the inclusion of Bootstrap */
        height: 29px;
    }

    .selectize-control > .selectize-dropdown {
        top: 36px;
    }
    /* Some additional styling to demonstrate that append-to-body helps achieve the proper z-index layering. */
    .select-box {
      background: #fff;
      position: relative;
      z-index: 1;
    }
    .alert-info.positioned {
      margin-top: 1em;
      position: relative;
      z-index: 10000; /* The select2 dropdown has a z-index of 9999 */
    }
</style>

${ ui.includeFragment("appui", "messages", [ codes: [
        "orderentryui.pastAction.REVISE",
        "orderentryui.pastAction.DISCONTINUE"
] ])}

${ ui.includeFragment("coreapps", "patientHeader", [ patient: patient ]) }

<div id="drug-orders-app" ng-controller="DrugOrdersCtrl" ng-init='init()'>
    <div class="ui-tabs">
        <ul class="ui-tabs-nav ui-helper-reset ui-helper-clearfix ui-widget-header">
            <li class="ui-state-default ui-corner-top ui-tabs-active ui-state-active">
                    <a class="ui-tabs-anchor">
                        Prescription Orders
                    </a>
            </li>
        </ul>

        <div class="ui-tabs-panel ui-widget-content">

            <form id="new-order" class="sized-inputs css-form" name="newOrderForm" novalidate>
                <p>
                    <span ng-repeat="setting in careSettings">
                        <input  type="radio" name="careSetting" ng-model="careSetting"
                                ng-value="setting" ng-click="setCareSetting(setting)"/>{{ setting | omrsDisplay }}<br/>
                    </span>
                </p>
                <p>
                    <span ng-show="newDraftDrugOrder.action === 'NEW'">
                        <label>New order for:</label>
                        <select-drug ng-model="newDraftDrugOrder.drug" placeholder="Drug" size="40" support-free-text></select-drug>
                    </span>
                    <strong ng-show="newDraftDrugOrder.action === 'REVISE'">
                        Revised order for: {{ newDraftDrugOrder.drug.display }}
                    </strong>
                </p>

                <p ng-show="newDraftDrugOrder.drug || newDraftDrugOrder.drugNonCoded">
                    <label class="heading instructions">
                        <span>Instructions</span>
                        <a ng-repeat="dosingType in dosingTypes" tabindex="-1"
                           ng-click="newDraftDrugOrder.dosingType = dosingType.javaClass"
                           ng-class="{ active: newDraftDrugOrder.dosingType == dosingType.javaClass }">
                            <i class="{{ dosingType.icon }}"></i>
                            {{ dosingType.display }}
                        </a>
                    </label>

                    <span ng-if="newDraftDrugOrder.dosingType == 'org.openmrs.SimpleDosingInstructions'">
                        <input ng-model="newDraftDrugOrder.dose" type="number" placeholder="Dose" min="0" required/>
                        <select-concept-from-list ng-model="newDraftDrugOrder.doseUnits" concepts="doseUnits" placeholder="Units" size="5" required></select-concept-from-list>

                        <select-order-frequency ng-model="newDraftDrugOrder.frequency" frequencies="frequencies" placeholder="Frequency" required></select-order-frequency>

                        <select-concept-from-list ng-model="newDraftDrugOrder.route" concepts="routes" placeholder="Route" size="20" required></select-concept-from-list>
                        <br/>

                        <label ng-class="{ disabled: !newDraftDrugOrder.asNeededCondition }">As needed for</label>
                        <input ng-model="newDraftDrugOrder.asNeededCondition" type="text" size="30" placeholder="reason (optional)"/>
                        <br/>

                        <label ng-class="{ disabled: !newDraftDrugOrder.duration }">For</label>
                        <input ng-model="newDraftDrugOrder.duration" type="number" min="0" placeholder="Duration"/>
                        <select-concept-from-list ng-model="newDraftDrugOrder.durationUnits" concepts="durationUnits" placeholder="Units" size="5" required-if="newDraftDrugOrder.duration"></select-concept-from-list>
                        <label ng-class="{ disabled: !newDraftDrugOrder.duration }">total</label>
                        <br/>
                        <textarea ng-model="newDraftDrugOrder.dosingInstructions" rows="2" cols="60" placeholder="Additional instruction not covered above"></textarea>
                    </span>

                    <span ng-if="newDraftDrugOrder.dosingType == 'org.openmrs.FreeTextDosingInstructions'">
                        <textarea ng-model="newDraftDrugOrder.dosingInstructions" rows="4" cols="60" placeholder="Complete instructions"></textarea>
                    </span>


                    <span ng-if="newDraftDrugOrder.dosingType == 'org.openmrs.FreeTextDosingInstructions' && careSetting.careSettingType == 'OUTPATIENT'">
                        <input ng-model="newDraftDrugOrder.quantity" type="number" placeholder="Quantity" min="0" size="10" required/>
                        <select-concept-from-list ng-model="newDraftDrugOrder.quantityUnits" concepts="quantityUnits" placeholder="Units" size="10" required></select-concept-from-list>
                    </span>
                </p>

                <p ng-show="newDraftDrugOrder.drug">
                    <button type="submit" class="confirm right" ng-disabled="newOrderForm.\$invalid" ng-click="addNewDraftOrder()">Add</button>
                    <button class="cancel" ng-click="cancelNewDraftOrder()">Cancel</button>
                </p>
            </form>

            <div id="draft-orders" ng-show="draftDrugOrders.length > 0">
                <h3>Unsaved Draft Orders ({{ draftDrugOrders.length }})</h3>
                <table>
                    <tr class="draft-order" ng-repeat="order in draftDrugOrders">
                        <td>
                            {{ order.action }}
                            {{ order | dates }}
                        </td>
                        <td>
                            {{ order | instructions }}
                            <span ng-show="order.action == 'DISCONTINUE'">
                                <br/>
                                For: <input ng-model="order.orderReasonNonCoded" class="dc-reason" type="text" placeholder="reason" size="40"/>
                            </span>
                        </td>
                        <td class="actions">
                            <a ng-click="editDraftDrugOrder(order)"><i class="icon-pencil edit-action"></i></a>
                            <a ng-click="cancelDraftDrugOrder(order)"><i class="icon-remove delete-action"></i></a>
                        </td>
                    </tr>
                </table>

                <div class="actions">
                    <div class="signature">
                        Signing as ${ ui.format(sessionContext.currentProvider) } on (auto-generated timestamp)
                        <img ng-show="loading" src="${ ui.resourceLink("uicommons", "images/spinner.gif") }"/>
                    </div>
                </div>
                <div class="actions">
                        <ui-select ng-model="encounterRole.selected" theme="selectize" style="width: 300px;" ng-disabled="encounterRole.loading">
                                            <ui-select-match placeholder="placed as...">{{ \$select.selected.display }}</ui-select-match>
                                            <ui-select-choices repeat="role in encounterRoles | filter: \$select.search">
                                                <span ng-bind-html="role.trustedDisplay | highlight: \$select.search"></span>
                                            </ui-select-choices>
                                        </ui-select>
                </div>
                <div class="actions">
                    <button class="confirm right" ng-disabled="loading || !encounterRole.selected" ng-click="signAndSaveDraftDrugOrders()">Sign and Save</button>
                    <button class="cancel" ng-click="cancelAllDraftDrugOrders()">
                        {{ draftDrugOrders.length > 1 ? "Discard All" : "Discard" }}
                    </button>
                </div>
            </div>

            <h3>Active Drug Orders</h3>
            <span ng-show="activeDrugOrders.loading">${ ui.message("uicommons.loading.placeholder") }</span>
            <span ng-hide="activeDrugOrders.loading || activeDrugOrders.length > 0">None</span>
            <table ng-hide="activeDrugOrders.loading">
                <tr ng-repeat="order in activeDrugOrders">
                    <td ng-class="{ 'will-replace': replacementFor(order) }">
                        {{ order | dates }}
                    </td>
                    <td ng-class="{ 'will-replace': replacementFor(order) }">
                        {{ order | instructions }}
                    </td>
                    <td class="actions">
                        <a ng-show="!replacementFor(order)" ng-click="reviseOrder(order)">
                            <i class="icon-pencil edit-action"></i>
                        </a>
                        <a ng-show="!replacementFor(order)" ng-click="discontinueOrder(order)">
                            <i class="icon-remove delete-action"></i>
                        </a>
                        <span ng-show="replacementFor(order)">
                            will {{ replacementFor(order).action }}
                        </span>
                    </td>
                </tr>
            </table>

            <h3>Past Drug Orders</h3>
            <span ng-show="pastDrugOrders.loading">${ ui.message("uicommons.loading.placeholder") }</span>
            <span ng-hide="pastDrugOrders.loading || pastDrugOrders.length > 0">None</span>
            <table id="past-drug-orders" ng-hide="pastDrugOrders.loading">
                <tr ng-repeat="order in pastDrugOrders">
                    <td>
                        {{ replacementForPastOrder(order) | replacement }}
                    </td>
                    <td>
                        {{ order | dates }}
                    </td>
                    <td>
                        {{ order | instructions }}
                    </td>
                </tr>
            </table>
        </div>
    </div>

</div>

<script type="text/javascript">
    // manually bootstrap angular app, in case there are multiple angular apps on a page
    angular.bootstrap('#drug-orders-app', ['drugOrders']);
</script>