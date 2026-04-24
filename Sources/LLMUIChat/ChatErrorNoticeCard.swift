import SwiftUI

struct ChatErrorNoticeCard: View {
    let error: ChatErrorPresentation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Label(error.title, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.red.opacity(0.2), lineWidth: 1)
            }

            Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
