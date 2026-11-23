//
//  HomeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults

struct HomeView: View {
    @State private var viewModel = QuotaStatusViewModel.shared

    @Default(.hourlyQuota) private var hourlyQuota
    @Default(.dailyQuota) private var dailyQuota
    @Default(.monthlyQuota) private var monthlyQuota

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center) {
                    IndicatorLEDView(statusSuccess: $viewModel.statusSuccess)
                    StatusMessageView(statusSuccess: $viewModel.statusSuccess,
                                      errorMessage: $viewModel.errorMessage)
                    Spacer()
                    Button(action: viewModel.retryRequest) {
                        Text("homepage.status.retry")
                    }
                    .padding(.trailing, 10)
                    .keyboardShortcut("r", modifiers: .command)
                }
                .frame(height: 35)
            }
            Section {
                QuotaItem(title: "homepage.quota.hourly",
                          systemImage: "clock.fill",
                          quotaItem: currentHourlyQuota)
                QuotaItem(title: "homepage.quota.daily",
                          systemImage: "sun.horizon.fill",
                          quotaItem: currentDailyQuota)
                QuotaItem(title: "homepage.quota.monthly",
                          systemImage: "calendar",
                          quotaItem: currentMonthlyQuota)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollDisabled(true)
        .scrollIndicators(.never)
        .task {
            await viewModel.performRequest()
        }
        .onDisappear {
            viewModel.statusSuccess = nil
        }
    }

    // MARK: Private

    private var currentHourlyQuota: UserQuota {
        viewModel.hourlyQuota ?? hourlyQuota
    }

    private var currentDailyQuota: UserQuota {
        viewModel.dailyQuota ?? dailyQuota
    }

    private var currentMonthlyQuota: UserQuota {
        viewModel.monthlyQuota ?? monthlyQuota
    }
}

#Preview {
    HomeView()
}
