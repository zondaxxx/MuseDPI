//
//  SettingsInfoView.swift
//  SwByeDPI
//
//  Created by developer on 02.03.2026.
//

import SwiftUI

struct SettingsStaticInfoView: View {
    
    fileprivate let title: String
    fileprivate let text: String
    fileprivate let leadingIcon: Image
    fileprivate let showsDisclosure: Bool
    
    init(title: String, text: String, leadingIcon: Image, showsDisclosure: Bool = true) {
        self.title = title
        self.text = text
        self.leadingIcon = leadingIcon
        self.showsDisclosure = showsDisclosure
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PalkaIconBadge(image: leadingIcon)

            VStack(alignment: .leading, spacing: 4, content: {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(PalkaDesign.textMuted)
                Text(text)
                    .font(.system(size: 14, weight: .regular))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(PalkaDesign.textPrimary)
                    .lineSpacing(3)
            })

            Spacer(minLength: 4)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(PalkaDesign.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .palkaCard(radius: 16)
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 12.0) {
        SettingsStaticInfoView(title: "Some category", text: "Category Value", leadingIcon: Image(R.image.icInfo), showsDisclosure: false)
        SettingsStaticInfoView(title: "Some category long-long-long text with additional info...", text: "Category Value", leadingIcon: Image(R.image.icInfo))
        SettingsStaticInfoView(title: "Some category long-long-long text with additional info...", text: "Category Value long-long-long text with additional info", leadingIcon: Image(R.image.icInfo))
    }
}
#endif
