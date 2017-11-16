<%
    def careSettings = activeTestOrders.collect{it.careSetting}.unique()
%>

<style type="text/css">
    .info-body.active-drug-orders h4 {
        font-size: 1em;
    }
    .info-body.active-drug-orders h4:first-child {
        margin-top: 0px;
    }
</style>

<div class="info-section">

    <div class="info-header">
        <i class="icon-camera"></i>
        <h3>${ ui.message("orderentryui.patientdashboard.activeTestOrders").toUpperCase() }</h3>
        <% if (context.hasPrivilege("App: orderentryui.drugOrders")) { %>
            <a href="${ ui.pageLink("orderentryui", "testOrders", [patient: patient.id, returnUrl: ui.thisUrl()]) }">
                <i class="icon-share-alt edit-action right" title="${ ui.message("coreapps.edit") }"></i>
            </a>
        <% } %>
    </div>

    <div class="info-body active-drug-orders">
        <% if (!activeTestOrders) { %>
            ${ ui.message("emr.none") }
        <% } else { %>

            <% careSettings.each { careSetting -> %>
                <ul>
                    <% activeTestOrders.findAll{ it.careSetting == careSetting }.each { %>
                    <li>
                        <label>${ ui.format(it.concept) }</label>
                        <small><strong>Scheduled for: </strong>${ ui.formatDatePretty(it.scheduledDate) }</small>
                    </li>
                    <% } %>
                </ul>
            <% } %>
        <% } %>
    </div>

</div>