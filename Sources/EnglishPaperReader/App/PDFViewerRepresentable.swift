@preconcurrency import AppKit
@preconcurrency import PDFKit
import SwiftUI

struct PDFViewerRepresentable: NSViewRepresentable {
    let pdfID: String
    let fileURL: URL
    let appearances: [Appearance]
    let onHoverAppearance: (Appearance, CGRect) -> Void
    let onHoverEnded: () -> Void
    let onTextSelection: (PDFSelectionCapture) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> PDFInteractiveContainerView {
        let view = PDFInteractiveContainerView()
        view.configure(with: fileURL, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: PDFInteractiveContainerView, context: Context) {
        nsView.updateDocument(url: fileURL)
        nsView.updateAppearanceHighlights(appearances)
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: PDFViewerRepresentable
        weak var pdfView: PDFInteractivePDFView?
        private var isApplyingProgrammaticSelection = false
        private var pendingHoverWorkItem: DispatchWorkItem?
        private let hoverDelay: TimeInterval = 0.45
        private var hoveredAppearanceID: String?

        init(parent: PDFViewerRepresentable) {
            self.parent = parent
        }

        func commitCurrentSelection(in pdfView: PDFInteractivePDFView) {
            guard
                let selection = pdfView.currentSelection,
                let page = selection.pages.first,
                let document = pdfView.document
            else {
                return
            }

            guard !isApplyingProgrammaticSelection else { return }

            let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return }

            let bounds = selection.bounds(for: page)
            let pageIndex = document.index(for: page)
            let snippet = PDFTextLocator.contextSnippet(for: selection, on: page)
            let lineCount = max(selection.selectionsByLine().count, 1)

            parent.onTextSelection(
                PDFSelectionCapture(
                    pdfID: parent.pdfID,
                    surface: text,
                    page: pageIndex,
                    boundingBox: bounds,
                    contextSnippet: snippet,
                    lineCount: lineCount
                )
            )
        }

        func mouseMoved(to point: NSPoint, in pdfView: PDFInteractivePDFView) {
            self.pdfView = pdfView
            guard
                let page = pdfView.page(for: point, nearest: true),
                let document = pdfView.document
            else {
                hoveredAppearanceID = nil
                pendingHoverWorkItem?.cancel()
                parent.onHoverEnded()
                return
            }

            let pointOnPage = pdfView.convert(point, to: page)
            let appearance = parent.appearances.first { appearance in
                guard appearance.page == document.index(for: page) else { return false }
                let hitRect = CGRect(
                    x: appearance.bboxX,
                    y: appearance.bboxY,
                    width: appearance.bboxWidth,
                    height: appearance.bboxHeight
                ).insetBy(dx: -3, dy: -3)
                return hitRect.contains(pointOnPage)
            }

            guard let appearance else {
                hoveredAppearanceID = nil
                pendingHoverWorkItem?.cancel()
                parent.onHoverEnded()
                return
            }

            if hoveredAppearanceID == appearance.id {
                return
            }

            hoveredAppearanceID = appearance.id
            let rect = pdfView.convert(
                CGRect(
                    x: appearance.bboxX,
                    y: appearance.bboxY,
                    width: appearance.bboxWidth,
                    height: appearance.bboxHeight
                ),
                from: page
            )
            pendingHoverWorkItem?.cancel()
            parent.onHoverEnded()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.parent.onHoverAppearance(appearance, rect)
            }
            pendingHoverWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: workItem)
        }

        func mouseExited() {
            hoveredAppearanceID = nil
            pendingHoverWorkItem?.cancel()
            parent.onHoverEnded()
        }

        @objc
        func jumpToAppearance(_ notification: Notification) {
            guard
                let appearance = notification.object as? Appearance,
                let pdfView,
                let document = pdfView.document,
                let page = document.page(at: appearance.page)
            else {
                return
            }

            pdfView.go(to: page)
            let targetRect = CGRect(
                x: appearance.bboxX,
                y: appearance.bboxY,
                width: appearance.bboxWidth,
                height: appearance.bboxHeight
            )
            let destinationPoint = CGPoint(
                x: targetRect.minX,
                y: max(targetRect.maxY + 72, targetRect.maxY)
            )
            let destination = PDFDestination(page: page, at: destinationPoint)
            pdfView.go(to: destination)
            isApplyingProgrammaticSelection = true
            pdfView.currentSelection = page.selection(for: targetRect)
            isApplyingProgrammaticSelection = false
        }

        @objc
        func zoomIn(_ notification: Notification) {
            guard
                let targetPDFID = notification.object as? String,
                targetPDFID == parent.pdfID,
                let pdfView
            else {
                return
            }

            pdfView.autoScales = false
            pdfView.zoomIn(self)
        }

        @objc
        func zoomOut(_ notification: Notification) {
            guard
                let targetPDFID = notification.object as? String,
                targetPDFID == parent.pdfID,
                let pdfView
            else {
                return
            }

            pdfView.autoScales = false
            pdfView.zoomOut(self)
        }

        @objc
        func fitToWindow(_ notification: Notification) {
            guard
                let targetPDFID = notification.object as? String,
                targetPDFID == parent.pdfID,
                let pdfView
            else {
                return
            }

            pdfView.autoScales = true
            pdfView.layoutDocumentView()
        }
    }
}

@MainActor
final class PDFInteractiveContainerView: NSView {
    private let pdfView = PDFInteractivePDFView(frame: .zero)
    private var loadedURL: URL?
    private var highlightedAppearanceIDs: [String] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pdfView)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        guard pdfView.autoScales else { return }
        pdfView.layoutDocumentView()
        let fittedScale = pdfView.scaleFactorForSizeToFit
        if fittedScale.isFinite, fittedScale > 0 {
            pdfView.scaleFactor = fittedScale
        }
    }

    func configure(with fileURL: URL, coordinator: PDFViewerRepresentable.Coordinator) {
        pdfView.viewerCoordinator = coordinator
        coordinator.pdfView = pdfView
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .windowBackgroundColor

        updateDocument(url: fileURL)
        updateAppearanceHighlights(coordinator.parent.appearances)

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(PDFViewerRepresentable.Coordinator.jumpToAppearance(_:)),
            name: .jumpToAppearance,
            object: nil
        )
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(PDFViewerRepresentable.Coordinator.zoomIn(_:)),
            name: .zoomInPDF,
            object: nil
        )
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(PDFViewerRepresentable.Coordinator.zoomOut(_:)),
            name: .zoomOutPDF,
            object: nil
        )
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(PDFViewerRepresentable.Coordinator.fitToWindow(_:)),
            name: .fitPDFToWindow,
            object: nil
        )
    }

    func updateDocument(url: URL) {
        guard loadedURL != url else { return }
        loadedURL = url
        pdfView.document = PDFDocument(url: url)
    }

    func updateAppearanceHighlights(_ appearances: [Appearance]) {
        let appearanceIDs = appearances.map(\.id).sorted()
        guard highlightedAppearanceIDs != appearanceIDs else { return }
        highlightedAppearanceIDs = appearanceIDs

        guard let document = pdfView.document else { return }

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where annotation is RegisteredWordHighlightAnnotation {
                page.removeAnnotation(annotation)
            }
        }

        for appearance in appearances {
            guard let page = document.page(at: appearance.page) else { continue }
            let bounds = CGRect(
                x: appearance.bboxX,
                y: appearance.bboxY,
                width: appearance.bboxWidth,
                height: appearance.bboxHeight
            ).insetBy(dx: -1, dy: -1)
            let annotation = RegisteredWordHighlightAnnotation(appearanceID: appearance.id, bounds: bounds)
            page.addAnnotation(annotation)
        }
    }
}

@MainActor
final class PDFInteractivePDFView: PDFView {
    weak var viewerCoordinator: PDFViewerRepresentable.Coordinator?
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let newTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newTrackingArea)
        trackingAreaRef = newTrackingArea
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        viewerCoordinator?.mouseMoved(to: point, in: self)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        viewerCoordinator?.mouseExited()
        super.mouseExited(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        viewerCoordinator?.commitCurrentSelection(in: self)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        guard autoScales else { return }
        layoutDocumentView()
        let fittedScale = scaleFactorForSizeToFit
        if fittedScale.isFinite, fittedScale > 0 {
            scaleFactor = fittedScale
        }
    }
}

@MainActor
final class RegisteredWordHighlightAnnotation: PDFAnnotation {
    let appearanceID: String

    init(appearanceID: String, bounds: CGRect) {
        self.appearanceID = appearanceID
        super.init(bounds: bounds, forType: .square, withProperties: nil)
        color = NSColor.systemYellow.withAlphaComponent(0.22)
        interiorColor = NSColor.systemYellow.withAlphaComponent(0.22)
        border = {
            let border = PDFBorder()
            border.lineWidth = 1
            return border
        }()
        shouldDisplay = true
        shouldPrint = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
