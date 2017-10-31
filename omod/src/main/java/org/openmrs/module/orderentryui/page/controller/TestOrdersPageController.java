package org.openmrs.module.orderentryui.page.controller;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.openmrs.CareSetting;
import org.openmrs.EncounterType;
import org.openmrs.Patient;
import org.openmrs.Visit;
import org.openmrs.api.EncounterService;
import org.openmrs.api.OrderService;
import org.openmrs.api.VisitService;
import org.openmrs.module.appui.UiSessionContext;
import org.openmrs.module.webservices.rest.web.ConversionUtil;
import org.openmrs.module.webservices.rest.web.representation.Representation;
import org.openmrs.ui.framework.UiUtils;
import org.openmrs.ui.framework.annotation.SpringBean;
import org.openmrs.ui.framework.page.PageModel;
import org.springframework.web.bind.annotation.RequestParam;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;


public class TestOrdersPageController {
	private Log log = LogFactory.getLog(getClass());

	public void get(@RequestParam("patient") Patient patient,
					@RequestParam(value="visit", required=false) Visit visit,
					@RequestParam(value = "careSetting", required = false) CareSetting careSetting,
					@SpringBean("encounterService") EncounterService encounterService,
					@SpringBean("visitService") VisitService visitService,
					@SpringBean("orderService") OrderService orderService,
					UiSessionContext sessionContext,
					UiUtils ui,
					PageModel model) {

		// HACK
		EncounterType orderEncounterType = encounterService.getAllEncounterTypes(false).get(0);

		List<CareSetting> careSettings = orderService.getCareSettings(false);


		Map<String, Object> jsonConfig = new LinkedHashMap<String, Object>();
		jsonConfig.put("patient", convertToFull(patient));
		jsonConfig.put("provider", convertToFull(sessionContext.getCurrentProvider()));
		jsonConfig.put("orderEncounterType", convertToFull(orderEncounterType));
		jsonConfig.put("careSettings", convertToFull(careSettings));
		if (careSetting != null) {
			jsonConfig.put("initialCareSetting", careSetting.getUuid());
		}

		// if Visit is provided in the URL put it in the model
		if (visit != null ) {
			jsonConfig.put("visit", convertToFull(visit));
		}


		model.put("patient", patient);
		model.put("jsonConfig", ui.toJson(jsonConfig));
	}

	private Object convertTo(Object object, Representation rep) {
		return object == null ? null : ConversionUtil.convertToRepresentation(object, rep);
	}

	private Object convertToFull(Object object) {
		return object == null ? null : ConversionUtil.convertToRepresentation(object, Representation.FULL);
	}
}
