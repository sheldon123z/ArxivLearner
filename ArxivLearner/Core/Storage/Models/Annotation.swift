import Foundation
import SwiftData

@Model
final class Annotation {
    var typeRaw: String
    var pageIndex: Int
    var rectX: Double
    var rectY: Double
    var rectWidth: Double
    var rectHeight: Double
    var colorHex: String
    var text: String
    var createdAt: Date

    @Relationship var paper: Paper?

    var annotationType: AnnotationType {
        get { AnnotationType(rawValue: typeRaw) ?? .highlight }
        set { typeRaw = newValue.rawValue }
    }

    init(
        type: AnnotationType = .highlight,
        pageIndex: Int = 0,
        rectX: Double = 0,
        rectY: Double = 0,
        rectWidth: Double = 0,
        rectHeight: Double = 0,
        colorHex: String = "FDCB6E",
        text: String = "",
        paper: Paper? = nil,
        createdAt: Date = .now
    ) {
        self.typeRaw = type.rawValue
        self.pageIndex = pageIndex
        self.rectX = rectX
        self.rectY = rectY
        self.rectWidth = rectWidth
        self.rectHeight = rectHeight
        self.colorHex = colorHex
        self.text = text
        self.paper = paper
        self.createdAt = createdAt
    }
}
