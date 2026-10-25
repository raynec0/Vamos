import SwiftUI

struct ReferenceListView: View {
    private let pages = CourseStore.shared.reference

    var body: some View {
        Group {
            List {
                Section {
                    ForEach(pages) { page in
                        NavigationLink {
                            ReferenceDetailView(page: page)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: page.icon)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.vRojo))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title).font(.body.weight(.semibold))
                                    Text(page.subtitle)
                                        .font(.spanish(14, weight: .regular).italic())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } footer: {
                    Text("表格里的红色西语都可以点一下听发音。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("语法手册")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ReferenceDetailView: View {
    let page: RefPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(page.sections.indices, id: \.self) { i in
                    sectionView(page.sections[i])
                }
            }
            .padding(16)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionView(_ section: RefSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.heading)
                .font(.headline)
            if let text = section.body {
                Text(text)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let table = section.table {
                tableView(table)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func tableView(_ table: RefTable) -> some View {
        let speakCols = Set(table.speak ?? [])
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                ForEach(table.columns.indices, id: \.self) { c in
                    Text(table.columns[c])
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
            Divider()
            ForEach(table.rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(table.rows[r].indices, id: \.self) { c in
                        cell(table.rows[r][c], speakable: speakCols.contains(c))
                    }
                }
                if r < table.rows.count - 1 {
                    Divider().opacity(0.5)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ text: String, speakable: Bool) -> some View {
        if speakable && !text.isEmpty {
            Button {
                TTS.shared.speak(text)
            } label: {
                Text(text)
                    .font(.spanish(16, weight: .medium))
                    .foregroundColor(.vRojo)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
        } else {
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
