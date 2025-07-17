import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "plunge_timer",
                displayName: "Plunge Timer",
                supportedFamilies: [
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianLarge,
                    .circularSmall,
                    .extraLarge,
                    .graphicCorner,
                    .graphicBezel,
                    .graphicCircular,
                    .graphicRectangular
                ]
            )
        ]
        handler(descriptors)
    }
    
    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Do any necessary work to support these newly shared complication descriptors
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(Date().addingTimeInterval(4 * 60 * 60)) // 4 hours from now
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = createTemplate(for: complication.family)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        var entries: [CLKComplicationTimelineEntry] = []
        
        // Create timeline entries for the next few hours
        for i in 1...min(limit, 4) {
            let entryDate = date.addingTimeInterval(TimeInterval(i * 3600)) // Every hour
            let template = createTemplate(for: complication.family)
            let entry = CLKComplicationTimelineEntry(date: entryDate, complicationTemplate: template)
            entries.append(entry)
        }
        
        handler(entries)
    }
    
    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(for: complication.family)
        handler(template)
    }
    
    // MARK: - Template Creation
    
    private func createTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {
        case .modularSmall:
            return createModularSmallTemplate()
        case .modularLarge:
            return createModularLargeTemplate()
        case .utilitarianSmall, .utilitarianLarge:
            return createUtilitarianTemplate()
        case .circularSmall:
            return createCircularSmallTemplate()
        case .extraLarge:
            return createExtraLargeTemplate()
        case .graphicCorner:
            return createGraphicCornerTemplate()
        case .graphicBezel:
            return createGraphicBezelTemplate()
        case .graphicCircular:
            return createGraphicCircularTemplate()
        case .graphicRectangular:
            return createGraphicRectangularTemplate()
        default:
            return createModularSmallTemplate()
        }
    }
    
    private func createModularSmallTemplate() -> CLKComplicationTemplateModularSmallSimpleImage {
        let template = CLKComplicationTemplateModularSmallSimpleImage()
        template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "thermometer.snowflake")!)
        template.imageProvider.tintColor = .cyan
        return template
    }
    
    private func createModularLargeTemplate() -> CLKComplicationTemplateModularLargeStandardBody {
        let template = CLKComplicationTemplateModularLargeStandardBody()
        template.headerTextProvider = CLKSimpleTextProvider(text: "❄️ Plunge")
        template.body1TextProvider = CLKSimpleTextProvider(text: "Cold Plunge Timer")
        template.body2TextProvider = CLKSimpleTextProvider(text: "Tap to start")
        return template
    }
    
    private func createUtilitarianTemplate() -> CLKComplicationTemplateUtilitarianSmallFlat {
        let template = CLKComplicationTemplateUtilitarianSmallFlat()
        template.textProvider = CLKSimpleTextProvider(text: "❄️")
        template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "timer")!)
        template.imageProvider?.tintColor = .cyan
        return template
    }
    
    private func createCircularSmallTemplate() -> CLKComplicationTemplateCircularSmallSimpleImage {
        let template = CLKComplicationTemplateCircularSmallSimpleImage()
        template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "thermometer.snowflake")!)
        template.imageProvider.tintColor = .cyan
        return template
    }
    
    private func createExtraLargeTemplate() -> CLKComplicationTemplateExtraLargeSimpleImage {
        let template = CLKComplicationTemplateExtraLargeSimpleImage()
        template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "thermometer.snowflake")!)
        template.imageProvider.tintColor = .cyan
        return template
    }
    
    private func createGraphicCornerTemplate() -> CLKComplicationTemplateGraphicCornerTextImage {
        let template = CLKComplicationTemplateGraphicCornerTextImage()
        template.textProvider = CLKSimpleTextProvider(text: "❄️")
        
        let image = UIImage(systemName: "thermometer.snowflake")!
        template.imageProvider = CLKFullColorImageProvider(fullColorImage: image.withTintColor(.cyan))
        
        return template
    }
    
    private func createGraphicBezelTemplate() -> CLKComplicationTemplateGraphicBezelCircularText {
        let template = CLKComplicationTemplateGraphicBezelCircularText()
        template.textProvider = CLKSimpleTextProvider(text: "Cold Plunge Timer")
        
        let circularTemplate = CLKComplicationTemplateGraphicCircularImage()
        let image = UIImage(systemName: "thermometer.snowflake")!
        circularTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: image.withTintColor(.cyan))
        
        template.circularTemplate = circularTemplate
        return template
    }
    
    private func createGraphicCircularTemplate() -> CLKComplicationTemplateGraphicCircularImage {
        let template = CLKComplicationTemplateGraphicCircularImage()
        let image = UIImage(systemName: "thermometer.snowflake")!
        template.imageProvider = CLKFullColorImageProvider(fullColorImage: image.withTintColor(.cyan))
        return template
    }
    
    private func createGraphicRectangularTemplate() -> CLKComplicationTemplateGraphicRectangularStandardBody {
        let template = CLKComplicationTemplateGraphicRectangularStandardBody()
        template.headerTextProvider = CLKSimpleTextProvider(text: "❄️ Plunge Timer")
        template.body1TextProvider = CLKSimpleTextProvider(text: "Ready for cold plunge")
        template.body2TextProvider = CLKSimpleTextProvider(text: "Tap to start session")
        return template
    }
}