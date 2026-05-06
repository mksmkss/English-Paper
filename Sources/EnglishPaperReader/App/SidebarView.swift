import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    private var rootNodes: [FolderNode] {
        workspace.folderTree.filter { $0.folder != nil }
    }

    private var uncategorizedNode: FolderNode? {
        workspace.folderTree.first(where: { $0.folder == nil })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    Task {
                        await workspace.promptAddPDF(to: workspace.selectedFolderID)
                    }
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .help("Import a PDF into the current library or selected folder")
                .accessibilityLabel(Text("Add PDF"))

                Button {
                    workspace.requestAddFolder(parentID: workspace.selectedFolderID)
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.bordered)
                .help("Create a folder to organize PDFs")
                .accessibilityLabel(Text("New Folder"))
            }
            .frame(maxWidth: .infinity)
            .padding(12)

            List {
                if let message = workspace.startupMessage {
                    Section("Startup") {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Library") {
                    ForEach(rootNodes) { node in
                        FolderTreeRow(node: node)
                    }

                    if workspace.editingFolderDraft?.mode == .create,
                       workspace.editingFolderDraft?.parentID == nil {
                        InlineFolderEditorRow()
                    }

                    if let uncategorizedNode {
                        UncategorizedRow(node: uncategorizedNode)
                    }
                }
            }
            .listStyle(.sidebar)
            .background(
                SidebarKeyboardBridge {
                    workspace.beginRenameSelectedFolder()
                }
            )
            .onDrop(of: [UTType.plainText], delegate: SidebarDropDelegate(target: .libraryRoot, workspace: workspace))
        }
        .navigationTitle("Explorer")
    }
}

private struct FolderTreeRow: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let node: FolderNode

    var body: some View {
        if let folder = node.folder {
            DisclosureGroup(isExpanded: expansionBinding(for: folder.id)) {
                ForEach(node.children) { child in
                    FolderTreeRow(node: child)
                }

                if workspace.editingFolderDraft?.mode == .create,
                   workspace.editingFolderDraft?.parentID == folder.id {
                    InlineFolderEditorRow()
                }

                ForEach(node.pdfs, id: \.id) { pdf in
                    PDFSidebarRow(pdf: pdf)
                }
            } label: {
                FolderSidebarRow(folder: folder, onTapToggle: {
                    let id = folder.id
                    if workspace.expandedFolderIDs.contains(id) {
                        workspace.expandedFolderIDs.remove(id)
                    } else {
                        workspace.expandedFolderIDs.insert(id)
                    }
                })
            }
        }
    }

    private func expansionBinding(for folderID: String) -> Binding<Bool> {
        Binding(
            get: { workspace.expandedFolderIDs.contains(folderID) },
            set: { isExpanded in
                if isExpanded {
                    workspace.expandedFolderIDs.insert(folderID)
                } else {
                    workspace.expandedFolderIDs.remove(folderID)
                }
            }
        )
    }
}

private struct FolderSidebarRow: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let folder: Folder
    var onTapToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)

            if isEditing {
                InlineFolderNameField()
            } else {
                Text(folder.name)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Menu {
                Button("Add Subfolder") {
                    workspace.requestAddFolder(parentID: folder.id)
                }
                Button("Rename") {
                    workspace.requestRenameFolder(folder)
                }
                Button("Add PDF") {
                    Task {
                        await workspace.promptAddPDF(to: folder.id)
                    }
                }
                Divider()
                Button("Delete Folder", role: .destructive) {
                    Task {
                        await workspace.deleteFolder(folder.id)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Folder options")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            workspace.selectFolder(folder.id)
            onTapToggle?()
        }
        .onDrop(of: [UTType.plainText], delegate: SidebarDropDelegate(target: .folder(folder.id), workspace: workspace))
        .onDrag {
            NSItemProvider(object: SidebarDragItem.folder(folder.id).payload as NSString)
        }
    }

    private var isEditing: Bool {
        workspace.editingFolderDraft?.id == folder.id
    }

    private var rowBackground: some ShapeStyle {
        workspace.selectedFolderID == folder.id ? Color.accentColor.opacity(0.16) : Color.clear
    }
}

private struct UncategorizedRow: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let node: FolderNode

    var body: some View {
        DisclosureGroup(isExpanded: uncategorizedExpansionBinding) {
            ForEach(node.pdfs, id: \.id) { pdf in
                PDFSidebarRow(pdf: pdf)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.secondary)
                Text("Uncategorized")
                Spacer(minLength: 8)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                uncategorizedExpansionBinding.wrappedValue.toggle()
            }
        }
        .onDrop(of: [UTType.plainText], delegate: SidebarDropDelegate(target: .uncategorized, workspace: workspace))
    }

    private var uncategorizedExpansionBinding: Binding<Bool> {
        Binding(
            get: { workspace.expandedFolderIDs.contains(FolderNode.uncategorizedID) },
            set: { isExpanded in
                if isExpanded {
                    workspace.expandedFolderIDs.insert(FolderNode.uncategorizedID)
                } else {
                    workspace.expandedFolderIDs.remove(FolderNode.uncategorizedID)
                }
            }
        )
    }
}

private struct InlineFolderEditorRow: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            InlineFolderNameField()

            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
        .onAppear {
            isFocused = true
        }
        .focused($isFocused)
    }
}

private struct InlineFolderNameField: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Folder name", text: draftNameBinding)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onAppear {
                isFocused = true
            }
            .onSubmit {
                saveDraft()
            }
            .onExitCommand {
                workspace.cancelFolderEditing()
            }
    }

    private var draftNameBinding: Binding<String> {
        Binding(
            get: { workspace.editingFolderDraft?.name ?? "" },
            set: { newValue in
                guard var draft = workspace.editingFolderDraft else { return }
                draft.name = newValue
                workspace.editingFolderDraft = draft
            }
        )
    }

    private func saveDraft() {
        guard let draft = workspace.editingFolderDraft else { return }
        Task {
            await workspace.saveFolderDraft(draft)
        }
    }
}

private struct PDFSidebarRow: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let pdf: PDFRecord

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
            Text(pdf.filename)
                .lineLimit(1)
            Spacer(minLength: 8)
            if pdf.isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
            Menu {
                if pdf.isMissing {
                    Button("Relink File") {
                        Task {
                            await workspace.promptRelinkPDF(pdf)
                        }
                    }
                }
                if pdf.folderID != nil {
                    Button("Remove from Folder") {
                        Task {
                            await workspace.movePDF(pdf.id, to: nil)
                        }
                    }
                }
                Divider()
                Button("Remove PDF", role: .destructive) {
                    Task {
                        await workspace.deletePDF(pdf.id)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("PDF options")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(workspace.selectedPDFID == pdf.id ? Color.accentColor.opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            workspace.selectPDF(pdf.id)
            workspace.selectFolder(pdf.folderID)
        }
        .onDrag {
            NSItemProvider(object: SidebarDragItem.pdf(pdf.id).payload as NSString)
        }
    }
}

private enum SidebarDropTarget {
    case folder(String)
    case uncategorized
    case libraryRoot
}

private enum SidebarDragItem {
    case folder(String)
    case pdf(String)

    var payload: String {
        switch self {
        case let .folder(id):
            return "folder:\(id)"
        case let .pdf(id):
            return "pdf:\(id)"
        }
    }

    init?(payload: String) {
        if let value = payload.split(separator: ":", maxSplits: 1).map(String.init) as [String]?,
           value.count == 2 {
            switch value[0] {
            case "folder":
                self = .folder(value[1])
            case "pdf":
                self = .pdf(value[1])
            default:
                return nil
            }
        } else {
            return nil
        }
    }
}

private struct SidebarDropDelegate: DropDelegate {
    let target: SidebarDropTarget
    let workspace: WorkspaceViewModel

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText])
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let payloadString: String?
            if let data = item as? Data {
                payloadString = String(data: data, encoding: .utf8)
            } else if let string = item as? String {
                payloadString = string
            } else if let nsString = item as? NSString {
                payloadString = nsString as String
            } else {
                payloadString = nil
            }

            guard let payloadString,
                  let dragItem = SidebarDragItem(payload: payloadString.trimmingCharacters(in: .controlCharacters)) else { return }

            Task { @MainActor in
                switch (dragItem, target) {
                case let (.pdf(pdfID), .folder(folderID)):
                    await workspace.movePDF(pdfID, to: folderID)
                case let (.pdf(pdfID), .uncategorized):
                    await workspace.movePDF(pdfID, to: nil)
                case let (.pdf(pdfID), .libraryRoot):
                    await workspace.movePDF(pdfID, to: nil)
                case let (.folder(folderID), .folder(parentID)):
                    await workspace.moveFolder(folderID, to: parentID)
                case let (.folder(folderID), .uncategorized):
                    await workspace.moveFolder(folderID, to: nil)
                case let (.folder(folderID), .libraryRoot):
                    await workspace.moveFolder(folderID, to: nil)
                }
            }
        }

        return true
    }
}

private struct SidebarKeyboardBridge: NSViewRepresentable {
    let onReturn: () -> Void

    func makeNSView(context: Context) -> SidebarKeyboardView {
        let view = SidebarKeyboardView()
        view.onReturn = onReturn
        return view
    }

    func updateNSView(_ nsView: SidebarKeyboardView, context: Context) {
        nsView.onReturn = onReturn
    }
}

private final class SidebarKeyboardView: NSView {
    var onReturn: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installMonitorIfNeeded()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == 36 || event.keyCode == 76 else { return event }
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else { return event }
            guard window?.isKeyWindow == true else { return event }
            guard !(window?.firstResponder is NSTextView) else { return event }

            onReturn?()
            return nil
        }
    }
}
