import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appContext: AppContext
    @StateObject private var workspace = WorkspaceViewModel()

    var body: some View {
        WorkspaceRootView()
            .environmentObject(workspace)
            .task {
                workspace.configure(using: appContext)
                await workspace.loadInitialData()
            }
            .navigationTitle(workspace.windowTitle)
            .alert(workspace.errorTitle, isPresented: $workspace.isShowingError) {
                Button("OK") {
                    workspace.clearError()
                }
            } message: {
                Text(workspace.errorMessage ?? "Unknown error")
            }
            .sheet(item: $workspace.pendingRegistration) { selection in
                QuickRegisterSheet(selection: selection)
                    .environmentObject(workspace)
            }
            .sheet(item: $workspace.editingFolderDraft) { draft in
                FolderEditorSheet(draft: draft)
                    .environmentObject(workspace)
            }
            .onAppear {
                if workspace.startupMessage == nil {
                    workspace.startupMessage = appContext.startupMessage
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestAddPDFCommand)) { _ in
                Task {
                    await workspace.promptAddPDF(to: workspace.selectedFolderID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestNewFolderCommand)) { _ in
                workspace.requestAddFolder(parentID: workspace.selectedFolderID)
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleWordPanelCommand)) { _ in
                workspace.toggleWordPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomInPDFCommand)) { _ in
                workspace.zoomInPDF()
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomOutPDFCommand)) { _ in
                workspace.zoomOutPDF()
            }
            .onReceive(NotificationCenter.default.publisher(for: .fitPDFToWindowCommand)) { _ in
                workspace.fitPDFToWindow()
            }
    }
}

private struct WorkspaceRootView: View {
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
            } detail: {
                WorkspaceContentView()
            }
            if workspace.isWordPanelVisible {
                Divider()
                WordPanelView()
                    .frame(minHeight: 220, idealHeight: 260, maxHeight: 320)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                PDFZoomToolbarControls()
                GitHubToolbarControls(baseDirectory: appContext.paths.baseDirectory)
            }
        }
    }
}

private struct PDFZoomToolbarControls: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                workspace.zoomOutPDF()
            } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .disabled(!workspace.hasSelectedPDF)
            .help("Zoom out")

            Button {
                workspace.fitPDFToWindow()
            } label: {
                Label("Fit to Window", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .disabled(!workspace.hasSelectedPDF)
            .help("Fit PDF to window")

            Button {
                workspace.zoomInPDF()
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .disabled(!workspace.hasSelectedPDF)
            .help("Zoom in")
        }
    }
}

private struct WorkspaceContentView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        HSplitView {
            PDFWorkspaceView()
                .frame(minWidth: 520, maxWidth: .infinity)

            if workspace.selectedWord != nil {
                InspectorView()
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
            }
        }
    }
}
