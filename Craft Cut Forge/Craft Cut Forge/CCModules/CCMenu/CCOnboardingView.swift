//
//  CCOnboardingView.swift
//  Craft Cut Forge
//
//

import SwiftUI

struct CCMenuContainer: View {
    @AppStorage("firstOpenSC") var firstOpen: Bool = true
    
    var body: some View {
        ZStack {
            if firstOpen {
                CCOnboardingView(getStartBtnTapped: {
                    firstOpen = false
                })
            } else {
                RootView()
                    .environmentObject(WorkshopStore())
            }
        }
    }
}

struct CCOnboardingView: View {
    var getStartBtnTapped: () -> ()
    @State var count = 0
    
    var onbIcon: Image {
        switch count {
        case 0:
            Image(.onboardingIcon1CC)
        case 1:
            Image(.onboardingIcon2CC)
        case 2:
            Image(.onboardingIcon3CC)
        case 3:
            Image(.onboardingIcon4CC)
        default:
            Image(.onboardingIcon1CC)
        }
    }
    
    var onbTitle: String {
        switch count {
        case 0:
            "Use Existing Materials"
        case 1:
            "Plan Your Build"
        case 2:
            "Perfect Timing"
        case 3:
            "Unlock New Styles"
        default:
            "Spin Your Meals"
        }
    }
    
    var onbDescription: String {
        switch count {
        case 0:
            "Track and organize materials in one place."
        case 1:
            "Organize tasks and assign materials before you start."
        case 2:
            "Land in the target zone for bonus XP."
        case 3:
            "Earn XP and unlock workshop customization."
        default:
            ""
        }
    }
    
    var body: some View {
        VStack {
            
            Spacer()
            
            onbIcon
                .resizable()
                .scaledToFit()
            
            VStack(spacing: 16) {
                Text(onbTitle)
                    .font(.system(size: 28, weight: .black))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
                    .frame(height: 72)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            
            Spacer()
            
            VStack {
                
                Text(onbDescription)
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 32)
                
                HStack(spacing: 6) {
                    if count == 0 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.appYellow)
                            .frame(width: 22, height: 5)
                        
                    } else {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 6, height: 5)
                    }
                    
                    
                    if count == 1 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.appYellow)
                            .frame(width: 22, height: 5)

                    } else {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 6, height: 5)
                    }
                    
                    if count == 2 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.appYellow)
                            .frame(width: 22, height: 5)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 6, height: 5)
                    }
                    
                    if count == 3 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.appYellow)
                            .frame(width: 22, height: 5)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 6, height: 5)
                    }
                }
                .padding(.bottom, 16)
                
                VStack(spacing: 16) {
                    
                    Button {
                        if count < 3 {
                            count += 1
                        } else {
                            getStartBtnTapped()
                        }
                    } label: {
                        HStack {
                            Text(count != 3 ? count == 2 ? "Got It" : "Continue" : "Start Crafting")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.appYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 50))
                        .padding(.horizontal, 32)
                    }
                    VStack {
                        if count != 3 {
                            Button {
                                getStartBtnTapped()
                            } label: {
                                Text("Skip")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Skip")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .opacity(0)
                        }
                        
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.onbBg)
    }
    
    
    private func additionalInfoCell<Content: View>(
        text: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            content()
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
}

#Preview {
    CCMenuContainer()
}
