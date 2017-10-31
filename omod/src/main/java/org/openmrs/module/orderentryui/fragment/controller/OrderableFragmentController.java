package org.openmrs.module.orderentryui.fragment.controller;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.openmrs.Concept;
import org.openmrs.ConceptName;
import org.openmrs.ConceptSearchResult;
import org.openmrs.api.AdministrationService;
import org.openmrs.api.ConceptService;
import org.openmrs.module.appui.UiSessionContext;
import org.openmrs.module.orderentryui.OrderEntryUIConstants;
import org.openmrs.ui.framework.SimpleObject;
import org.openmrs.ui.framework.UiUtils;
import org.openmrs.ui.framework.annotation.SpringBean;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.RequestParam;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;

public class OrderableFragmentController {
    private Log log = LogFactory.getLog(getClass());

    public List<SimpleObject> search(UiSessionContext context,
                                     UiUtils ui,
                                     @SpringBean("adminService") AdministrationService administrationService,
                                     @SpringBean("conceptService") ConceptService conceptService,
                                     @RequestParam("term") String query,
                                     @RequestParam(value = "start", defaultValue = "0") Integer start,
                                     @RequestParam(value = "size", defaultValue = "50") Integer size) throws Exception {
        Concept testSet = null;
        String setUuid = administrationService.getGlobalProperty(OrderEntryUIConstants.GP_TEST_ORDER_CONCEPT_SET_UUID);
        if(StringUtils.hasText(setUuid)) {
            testSet = conceptService.getConceptByUuid(setUuid);
            if(testSet == null) {
                log.error("Configured " + OrderEntryUIConstants.GP_TEST_ORDER_CONCEPT_SET_UUID + " value is not " +
                        "associated with any concept");
            }
        }

        Locale locale = context.getLocale();
        if(testSet != null) {
            return getMatchingMembers(testSet.getSetMembers(), ui, locale, query);
        }

        // Otherwise search the all the orderable concepts.
        Locale [] locales = new Locale[] { locale, new Locale(locale.getLanguage()) };

        List<ConceptSearchResult> hits = conceptService.getOrderableConcepts(query, Arrays.asList(locales), false, null, null);
        List<SimpleObject> ret = new ArrayList<SimpleObject>();
        for (ConceptSearchResult hit : hits) {
            ret.add(simplify(hit, ui, locale));
        }
        return ret;
    }

    private List<SimpleObject> getMatchingMembers(List<Concept> members, UiUtils ui, Locale locale, String term) throws Exception{
        ConceptSearchResult result;
        ConceptName name;

        List<SimpleObject> objects = new ArrayList<SimpleObject>();
        for(Concept member: members) {
            name = findMatchingName(member, locale, term);
            if(name != null) {
                result = new ConceptSearchResult(null, member, name);
                objects.add(this.simplify(result, ui, locale));
            }
        }
        return objects;
    }

    private ConceptName findMatchingName(Concept concept, Locale locale, String term) {
        Iterator<ConceptName> iterator =  concept.getNames(new Locale(locale.getLanguage())).iterator();

        ConceptName name;
        while(iterator.hasNext()) {
            name = iterator.next();
            if(!name.isVoided() && name.getName().toLowerCase().contains(term.toLowerCase())) {
                return name;
            }
        }

        return null;
    }

    private SimpleObject simplify(ConceptSearchResult result, UiUtils ui, Locale locale) throws Exception {
        SimpleObject simple = SimpleObject.fromObject(result, ui, "word", "conceptName.id", "conceptName.uuid",
                "conceptName.conceptNameType", "conceptName.name", "concept.id", "concept.uuid",
                "concept.conceptMappings.conceptMapType", "concept.conceptMappings.conceptReferenceTerm.code",
                "concept.conceptMappings.conceptReferenceTerm.name",
                "concept.conceptMappings.conceptReferenceTerm.conceptSource.name");

        Concept concept = result.getConcept();
        ConceptName preferredName = getPreferredName(locale, concept);
        PropertyUtils.setProperty(simple, "concept.preferredName", preferredName.getName());

        return simple;
    }

    private ConceptName getPreferredName(Locale locale, Concept concept) {
        ConceptName name = concept.getPreferredName(locale);
        if (name == null && (org.apache.commons.lang.StringUtils.isNotEmpty(locale.getCountry()) ||
                org.apache.commons.lang.StringUtils.isNotEmpty(locale.getVariant()))) {
            name = concept.getPreferredName(new Locale(locale.getLanguage()));
        }
        if (name == null) {
            name = concept.getName(locale);
        }
        return name;

    }
}
