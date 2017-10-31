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
    ui.includeJavascript("orderentryui", "test-orders.js")
    ui.includeJavascript("orderentryui", "select.min.js")

    ui.includeCss("uicommons", "ngDialog/ngDialog.min.css")
    ui.includeCss("orderentryui", "drugOrders.css")
    ui.includeCss("orderentryui", "select.min.css")
    ui.includeCss("orderentryui", "selectize.default.min.css")
%>
<script type="text/javascript">
    var breadcrumbs = [
        { icon: "icon-home", link: '/' + OPENMRS_CONTEXT_PATH + '/index.htm' },
        { label: "${ ui.format(patient.familyName) }, ${ ui.format(patient.givenName) }" ,
            link: '${ui.pageLink("coreapps", "clinicianfacing/patient", [patientId: patient.id])}'},
        { label: "Lab Orders" }
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

<div id="test-orders-app" ng-controller="TestOrdersCtrl" ng-init='init()'>
    <div class="ui-tabs">
        <ul class="ui-tabs-nav ui-helper-reset ui-helper-clearfix ui-widget-header">
            <li ng-repeat="setting in careSettings" class="ui-state-default ui-corner-top"
                ng-class="{ 'ui-tabs-active': setting == careSetting, 'ui-state-active': setting == careSetting }">
                    <a class="ui-tabs-anchor" ng-click="setCareSetting(setting)">
                        {{ setting | omrsDisplay }}
                    </a>
            </li>
        </ul>

        <div class="ui-tabs-panel ui-widget-content">

            <form id="new-order" class="sized-inputs css-form" name="newOrderForm" novalidate>
                <p>
                    <span ng-show="newDraftTestOrder.action === 'NEW'">
                        <label>New lab order for:</label>
                        <input type="text" id="order-concept" ng-model="newDraftTestOrder.concept"
                                        typeahead="concept as concept.conceptName.name for concept in searchConcepts(\$viewValue)"
                                        typeahead-editable="false" autocomplete="off" placeholder="Test..."
                                        ng-required="true" size="40" typeahead-wait-ms="20" typeahead-min-length="3"/>
                    </span>
                    <strong ng-show="newDraftTestOrder.action === 'REVISE'">
                        Revised order for: {{ newDraftTestOrder.concept.conceptName.name }}
                    </strong>
                </p>
                <p>
                    <label>Date Scheduled:</label>
                    <span class="angular-datepicker">
                        <input type="text" is-open="startDateOptions.opened" ng-model="startDate" min="{{startDateMin}}" max="endDate" show-weeks="false" datepicker-popup="dd MMM yyyy" readonly/>
                        <i class="icon-calendar small add-on" ng-click="startDateOptions.open(\$event)" ></i>
                        <a class="date-range-picker-clear-link add-on" ng-click="startDateOptions.clear($event)">{{ clearLinkText }}</a>
                    </span>
                </p>
                <p ng-show="newDraftTestOrder.concept">
                    <button type="submit" class="confirm right" ng-disabled="newOrderForm.\$invalid" ng-click="addNewDraftOrder()">Add</button>
                    <button class="cancel" ng-click="cancelNewDraftOrder()">Cancel</button>
                </p>
            </form>

            <div id="draft-orders" ng-show="draftTestOrders.length > 0">
                <h3>Unsaved Draft Orders ({{ draftTestOrders.length }})</h3>
                <table>
                    <tr class="draft-order" ng-repeat="order in draftTestOrders">
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
                        {{ draftTestOrders.length > 1 ? "Discard All" : "Discard" }}
                    </button>
                </div>
            </div>

            <!--
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
            -->
        </div>
    </div>

</div>

<script type="text/javascript">
    // manually bootstrap angular app, in case there are multiple angular apps on a page
    angular.bootstrap('#test-orders-app', ['testOrders']);
</script>