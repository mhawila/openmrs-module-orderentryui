/**
 * The contents of this file are subject to the OpenMRS Public License
 * Version 1.0 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://license.openmrs.org
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * Copyright (C) OpenMRS, LLC.  All Rights Reserved.
 */
package org.openmrs.module.orderentryui;


import org.apache.commons.lang.StringUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.openmrs.Concept;
import org.openmrs.GlobalProperty;
import org.openmrs.OrderFrequency;
import org.openmrs.api.AdministrationService;
import org.openmrs.api.ConceptService;
import org.openmrs.api.OrderService;
import org.openmrs.api.context.Context;
import org.openmrs.module.BaseModuleActivator;
import org.openmrs.util.OpenmrsConstants;

import java.util.ArrayList;
import java.util.List;

/**
 * This class contains the logic that is run every time this module is either started or stopped.
 */
public class OrderEntryUiActivator extends BaseModuleActivator {

    private Log log = LogFactory.getLog(getClass());

    @Override
    public void started() {
        AdministrationService as = Context.getAdministrationService();
        String orderFrequencyConvSetUuid = as.getGlobalProperty(OrderEntryUIConstants.GP_ORDER_FREQUENCIES_CONCEPT_SET_UUID);
        maybeSetGP(as, OpenmrsConstants.GP_DRUG_ROUTES_CONCEPT_UUID, "162394AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
        maybeSetGP(as, OpenmrsConstants.GP_DRUG_DOSING_UNITS_CONCEPT_UUID, "162384AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
        maybeSetGP(as, OpenmrsConstants.GP_DRUG_DISPENSING_UNITS_CONCEPT_UUID, "162402AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
        maybeSetGP(as, OpenmrsConstants.GP_DURATION_UNITS_CONCEPT_UUID, "1732AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
        ensureOrderFrequencies(Context.getOrderService(), Context.getConceptService(), orderFrequencyConvSetUuid);
    }

    private void maybeSetGP(AdministrationService service, String prop, String val) {
        GlobalProperty gp = service.getGlobalPropertyObject(prop);
        if (gp == null) {
            service.saveGlobalProperty(new GlobalProperty(prop, val));
        } else if (StringUtils.isEmpty(gp.getPropertyValue())) {
            gp.setPropertyValue(val);
            service.saveGlobalProperty(gp);
        }
    }

    private void ensureOrderFrequencies(OrderService orderService, ConceptService conceptService, String uuid) {

        List<OrderFrequency> existing = orderService.getOrderFrequencies(true);
        Concept frequencySetConcept = null;
        if (StringUtils.isNotEmpty(uuid)) {
            frequencySetConcept = conceptService.getConceptByUuid(uuid);
        }

        if (existing.size() == 0 && (StringUtils.isEmpty(uuid) || frequencySetConcept == null)) {
            log.error("The global property " + OrderEntryUIConstants.GP_ORDER_FREQUENCIES_CONCEPT_SET_UUID +
                    "value " + uuid + " is not valid");
        }

        if (frequencySetConcept != null) {
            List<Concept> members = frequencySetConcept.getSetMembers();
            if (members != null && members.size() > 0) {
                // add only missing members.
                List<Concept> alreadyWithFrequency = new ArrayList<Concept>();
                for (OrderFrequency frequency : existing) {
                    alreadyWithFrequency.add(frequency.getConcept());
                }

                List<Concept> toadd = new ArrayList<Concept>();
                if(alreadyWithFrequency.size() > 0) {
                    for(Concept concept: members) {
                        if(!alreadyWithFrequency.contains(concept)) {
                            toadd.add(concept);
                        }
                    }
                }

                for (Concept member : toadd) {
                    if (!member.isRetired()) {
                        OrderFrequency orderFrequency = new OrderFrequency();
                        orderFrequency.setConcept(member);
                        orderService.saveOrderFrequency(orderFrequency);
                    }
                }
            }
        }
    }

}
