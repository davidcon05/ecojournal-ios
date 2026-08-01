//
//  DashboardView.swift
//  EcoJournal
//
//  Created by David Contreras on 5/8/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Journal.lastModified, order: .reverse) private var journals: [Journal]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DashboardViewModel()

    init() {
        // No need to pass modelContext anymore
    }

      var body: some View {
          NavigationStack {
              ZStack {
                  mainContent
                  navigationTitle
                  floatingActionButton
              }
              .navigationDestination(isPresented: Binding(
                  get: { viewModel.shouldNavigateToJournal && viewModel.journalToUnlock != nil },
                  set: { if !$0 { viewModel.resetNavigation() } }
              )) {
                  if let journal = viewModel.journalToUnlock {
                      JournalContainerView(journal: journal)
                  }
              }
              .sheet(isPresented: $viewModel.showingCreateJournal) {
                  CreateJournalSheet(onCreate: { name in
                      viewModel.createJournal(name: name, modelContext: modelContext)
                  })
              }
              .sheet(isPresented: $viewModel.showingSettings) {
                  if let journal = viewModel.selectedJournal {
                      JournalSettingsSheet(
                          journal: .constant(journal),
                          onSave: { viewModel.saveJournalSettings(modelContext: modelContext) },
                          onDelete: { viewModel.deleteJournal(journal, modelContext: modelContext) },
                          keychainManager: viewModel.keychainManager
                      )
                  }
              }
              .sheet(isPresented: $viewModel.showingFilterSheet) {
                  FilterSheet(selectedOption: $viewModel.sortOption)
              }
              .sheet(isPresented: $viewModel.showingPasswordPrompt, onDismiss: {
                  viewModel.cancelPasswordPrompt()
              }) {
                  PasswordPromptSheet(
                      title: "Enter Password",
                      message: "This journal is password protected. Enter the password to continue.",
                      actionButtonText: "Unlock",
                      onSubmit: { password in
                          let isValid = viewModel.verifyPassword(password)
                          return isValid
                      },
                      lockoutMessage: viewModel.lockoutMessage,
                      onBiometricAuth: {
                          if let journal = viewModel.journalToUnlock {
                              return await viewModel.attemptBiometricUnlock(for: journal)
                          }
                          return false
                      },
                      keychainManager: viewModel.keychainManager
                  )
              }
              .sheet(isPresented: $viewModel.showingPasswordPromptForSettings, onDismiss: {
                  viewModel.cancelPasswordPromptForSettings()
              }) {
                  PasswordPromptSheet(
                      title: "Enter Password",
                      message: "This journal is password protected. Enter the password to access settings.",
                      actionButtonText: "Unlock",
                      onSubmit: { password in
                          return viewModel.verifyPasswordForSettings(password)
                      },
                      lockoutMessage: viewModel.lockoutMessage,
                      onBiometricAuth: {
                          if let journal = viewModel.journalForSettings {
                              return await viewModel.attemptBiometricUnlockForSettings(for: journal)
                          }
                          return false
                      },
                      keychainManager: viewModel.keychainManager
                  )
              }
              .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                  Button("OK") {
                      viewModel.errorMessage = nil
                  }
              } message: {
                  Text(viewModel.errorMessage ?? "")
              }
          }
      }

      // MARK: - Main Sections

      @ViewBuilder
      private var mainContent: some View {
          if journals.isEmpty {
              emptyState
          } else {
              journalsContent
          }
      }

      private var emptyState: some View {
          VStack(spacing: 24) {
              Spacer()

              ZStack {
                  Circle()
                      .fill(Color.primaryColor.opacity(0.1))
                      .frame(width: 120, height: 120)

                  Image(systemName: "book.closed.fill")
                      .font(.system(size: 50))
                      .foregroundColor(.primaryColor)
                      .accessibilityIdentifier(DashboardAccessibilityIdentifiers.emptyStateIcon)
              }

              VStack(spacing: 8) {
                  Text("No Journals Yet")
                      .font(.headline(24, weight: .bold))
                      .foregroundColor(.onSurface)
                      .accessibilityIdentifier(DashboardAccessibilityIdentifiers.emptyStateTitle)

                  Text("Start by adding a new journal")
                      .font(.body(16, weight: .regular))
                      .foregroundColor(.onSurfaceVariant)
                      .accessibilityIdentifier(DashboardAccessibilityIdentifiers.emptyStateMessage)
              }

              Spacer()
              Spacer()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.surfaceBackground)
      }

      private var journalsContent: some View {
          ScrollView {
              VStack(spacing: 24) {
                  searchAndFilter
                  journalsGrid
              }
          }
          .background(Color.surfaceBackground)
      }

      private var searchAndFilter: some View {
          HStack(alignment: .top, spacing: 12) {
              SearchBarWithDropdown(
                  text: $viewModel.searchText,
                  placeholder: "Search Journals...",
                  suggestions: viewModel.searchSuggestions(from: journals),
                  itemLabel: { $0.name },
                  itemIcon: { _ in "book.closed.fill" },
                  searchFieldIdentifier: DashboardAccessibilityIdentifiers.searchField,
                  onSelectSuggestion: { journal in
                      viewModel.requestJournalAccess(journal)
                  }
              )

              FilterButton(
                  isActive: viewModel.isFilterActive,
                  action: { viewModel.toggleFilterSheet() }
              )
              .accessibilityIdentifier(DashboardAccessibilityIdentifiers.filterButton)
          }
          .padding(.horizontal, 24)
          .padding(.top, 16)
      }

      private var journalsGrid: some View {
          LazyVGrid(columns: columns, spacing: 32) {
              ForEach(viewModel.filteredJournals(from: journals)) { journal in
                  JournalCardStyle(
                      journal: journal,
                      onTap: { viewModel.requestJournalAccess(journal) },
                      onSettingsTap: { viewModel.openSettings(for: journal) }
                  )
                  .accessibilityIdentifier(DashboardAccessibilityIdentifiers.journalCard(journal.id.uuidString))
              }
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 100)
      }


      private var navigationTitle: some View {
          Color.clear
              .navigationTitle("Journals")
              .navigationBarTitleDisplayMode(.large)
      }

      private var floatingActionButton: some View {
          VStack {
              Spacer()
              HStack {
                  Spacer()
                  Button(action: { viewModel.toggleCreateJournal() }) {
                      HStack(spacing: 8) {
                          Image(systemName: "plus.circle.fill")
                              .font(.system(size: 24))
                          Text("New Journal")
                              .font(.body(16, weight: .bold))
                      }
                      .foregroundColor(.white)
                      .padding(.horizontal, 24)
                      .padding(.vertical, 16)
                      .background(Color.primaryColor)
                      .clipShape(Capsule())
                      .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                  }
                  .accessibilityIdentifier(DashboardAccessibilityIdentifiers.newJournalButton)
                  .padding(.trailing, 24)
                  .padding(.bottom, 32)
              }
          }
      }

      // MARK: - Grid Configuration

      private var columns: [GridItem] {
          [
              GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 32)
          ]
      }
  }

  struct JournalCard: View {
      let journal: Journal
      @State private var isHovered = false

      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              // Card Image
              coverImage
                  .aspectRatio(4/5, contentMode: .fill)
                  .frame(maxWidth: .infinity)
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .shadow(color: .black.opacity(0.1), radius: isHovered ? 20 : 5, y: isHovered ? 10 : 2)
                  .scaleEffect(isHovered ? 1.02 : 1.0)
                  .animation(.easeOut(duration: 0.3), value: isHovered)

              // Card Info
              VStack(alignment: .leading, spacing: 4) {
                  Text(journal.name)
                      .font(.headline(20, weight: .bold))
                      .foregroundColor(isHovered ? .primaryColor : .onSurface)
                      .lineLimit(2)

                  HStack(spacing: 8) {
                      Text(journal.lastModified, format: .dateTime.month().day().year())
                          .font(.label(13, weight: .regular))

                      Circle()
                          .fill(Color.outlineVariant)
                          .frame(width: 3, height: 3)

                      Text("\(journal.logs.count) Log\(journal.logs.count == 1 ? "" : "s")")
                          .font(.label(13, weight: .regular))
                  }
                  .foregroundColor(.secondaryColor)
                  .textCase(.uppercase)
                  .tracking(1.2)
              }
          }
          .onHover { hovering in
              isHovered = hovering
          }
          .onTapGesture {
              // Navigate to journal tabs
          }
      }

      @ViewBuilder
      private var coverImage: some View {
          // Priority hierarchy:
          // 1. Password protected → Always show theme (privacy)
          // 2. Custom cover photo → Show coverPhotoURL
          // 3. Recent log media → Show first log's photo
          // 4. Empty journal → Show theme (fallback)

          if journal.isPasswordProtected {
              // PRIVACY: Always show theme for password-protected journals
              themeGradientView
          } else if let coverURL = journal.coverPhotoURL {
              // Custom cover photo - use direct Image loading for local files to avoid cache issues
              LocalImageView(url: coverURL, placeholder: themeGradientView)
          } else if let firstMediaURL = journal.logs.sorted(by: { $0.timestamp > $1.timestamp }).first?.mediaURLs.first {
              // First log's photo (sorted by timestamp to get most recent)
              LocalImageView(url: firstMediaURL, placeholder: themeGradientView)
          } else {
              // Empty journal fallback
              themeGradientView
          }
      }

      @ViewBuilder
      private var themeGradientView: some View {
          // Use stored theme from Journal
          let theme = JournalTheme.from(icon: journal.themeIcon, colorHex: journal.themeColorHex)
          ZStack {
              LinearGradient(
                  colors: [theme.color, theme.color.opacity(0.8)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
              )

              Image(systemName: theme.icon)
                  .font(.system(size: 80, weight: .light))
                  .foregroundColor(.white.opacity(0.3))
          }
      }
  }

  // MARK: - Journal Card Style

  struct JournalCardStyle: View {
      let journal: Journal
      let onTap: () -> Void
      let onSettingsTap: () -> Void
      @State private var isHovered = false

      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              // Colored header with image/icon
              ZStack(alignment: .topTrailing) {
                  // Priority hierarchy:
                  // 1. Password protected → Show theme (privacy)
                  // 2. Custom cover → Show coverPhotoURL
                  // 3. Recent log media → Show first log's photo
                  // 4. Empty journal → Show theme (fallback)

                  if journal.isPasswordProtected {
                      themeHeaderView
                  } else if let coverURL = journal.coverPhotoURL {
                      LocalImageView(url: coverURL, placeholder: themeHeaderView)
                          .frame(height: 140)
                  } else if let firstMediaURL = journal.logs.sorted(by: { $0.timestamp > $1.timestamp }).first?.mediaURLs.first {
                      LocalImageView(url: firstMediaURL, placeholder: themeHeaderView)
                          .frame(height: 140)
                  } else {
                      themeHeaderView
                  }

                  // Top-right icons: Lock (if protected) + Settings
                  HStack(spacing: 8) {
                      // Lock badge (only show if password protected)
                      if journal.isPasswordProtected {
                          Image(systemName: "lock.fill")
                              .font(.system(size: 12))
                              .foregroundColor(.white)
                              .padding(.horizontal, 10)
                              .padding(.vertical, 6)
                              .background(Color.secondaryColor)
                              .clipShape(Capsule())
                      }

                      // Settings button
                      Button(action: onSettingsTap) {
                          Image(systemName: "ellipsis.circle.fill")
                              .font(.system(size: 22))
                              .foregroundColor(.white)
                              .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                      }
                  }
                  .padding(12)
              }

              // Content section (white background)
              VStack(alignment: .leading, spacing: 8) {
                  // Title
                  Text(journal.name)
                      .font(.headline(18, weight: .bold))
                      .foregroundColor(.onSurface)
                      .lineLimit(2)

                  // Metadata with chevron
                  HStack(spacing: 8) {
                      Text(journal.lastModified, format: .dateTime.month().day().year())
                          .font(.label(12, weight: .regular))

                      Circle()
                          .fill(Color.outlineVariant)
                          .frame(width: 3, height: 3)

                      Text("\(journal.logs.count) Log\(journal.logs.count == 1 ? "" : "s")")
                          .font(.label(12, weight: .regular))

                      Spacer()

                      Image(systemName: "chevron.right")
                          .font(.system(size: 12, weight: .semibold))
                          .foregroundColor(.outline)
                  }
                  .foregroundColor(.secondaryColor)
                  .textCase(.uppercase)
              }
              .padding(16)
              .background(Color.white)
          }
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .stroke(Color.outlineVariant.opacity(0.3), lineWidth: 1)
          )
          .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
          .scaleEffect(isHovered ? 1.02 : 1.0)
          .animation(.easeOut(duration: 0.2), value: isHovered)
          .onHover { hovering in
              isHovered = hovering
          }
          .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .onTapGesture {
              onTap()
          }
      }

      @ViewBuilder
      private var themeHeaderView: some View {
          // Use stored theme from Journal
          let theme = JournalTheme.from(icon: journal.themeIcon, colorHex: journal.themeColorHex)
          ZStack {
              LinearGradient(
                  colors: [theme.color, theme.color.opacity(0.8)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
              )
              .frame(height: 140)

              Image(systemName: theme.icon)
                  .font(.system(size: 50, weight: .light))
                  .foregroundColor(.white.opacity(0.3))
          }
      }
  }

  struct CreateJournalSheet: View {
      @StateObject private var viewModel = CreateJournalViewModel()
      let onCreate: (String) -> Void

      var body: some View {
          BottomSheet(
              title: "New Journal",
              actionButtonText: "Create",
              isActionEnabled: viewModel.isValid,
              onAction: {
                  onCreate(viewModel.journalName)
                  viewModel.reset()
              }
          ) {
              VStack(alignment: .leading, spacing: 24) {
                  VStack(alignment: .leading, spacing: 8) {
                      Text("Journal Name")
                          .font(.body(13, weight: .regular))
                          .foregroundColor(.onSurfaceVariant)
                          .textCase(.uppercase)
                          .accessibilityIdentifier(DashboardAccessibilityIdentifiers.createJournalNameLabel)
                      TextField("Enter name", text: $viewModel.journalName)
                          .font(.body(17))
                          .textFieldStyle(.roundedBorder)
                          .accessibilityIdentifier(DashboardAccessibilityIdentifiers.createJournalNameField)
                  }

                  Text("Create a new journal to organize your field observations")
                      .font(.body(14))
                      .foregroundColor(.secondaryColor)
                      .accessibilityIdentifier(DashboardAccessibilityIdentifiers.createJournalDescription)
              }
          }
          .accessibilityIdentifier(DashboardAccessibilityIdentifiers.createJournalSheet)
      }
  }

#Preview("Dashboard") {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try! ModelContainer(for: Journal.self, Log.self, configurations: config)

      // April 2026 dates in ascending order
      let calendar = Calendar.current
      let april5 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!
      let april10 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!
      let april15 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15))!
      let april20 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 20))!
      let april25 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 25))!
      let april30 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 30))!

      // Journals with "River" in name
      let journal1 = Journal(name: "Cedar River Watershed")
      journal1.createdDate = april5
      journal1.lastModified = april5
      for i in 1...18 {
          journal1.logs.append(Log(notes: "Cedar River observation \(i)"))
      }

      let journal2 = Journal(name: "Snoqualmie River Basin")
      journal2.createdDate = april10
      journal2.lastModified = april10
      journal2.isPasswordProtected = true
      for i in 1...24 {
          journal2.logs.append(Log(notes: "River basin study \(i)"))
      }

      let journal3 = Journal(name: "Columbia River Gorge")
      journal3.createdDate = april15
      journal3.lastModified = april15
      for i in 1...42 {
          journal3.logs.append(Log(notes: "Gorge observation \(i)"))
      }

      // Journals with "Ri" but not "River"
      let journal4 = Journal(name: "Rice Creek Wetlands")
      journal4.createdDate = april20
      journal4.lastModified = april20
      for i in 1...15 {
          journal4.logs.append(Log(notes: "Wetland study \(i)"))
      }

      let journal5 = Journal(name: "Mount Ritter Expedition")
      journal5.createdDate = april25
      journal5.lastModified = april25
      journal5.isPasswordProtected = true
      for i in 1...33 {
          journal5.logs.append(Log(notes: "Mountain expedition \(i)"))
      }

      let journal6 = Journal(name: "Rim of the Pacific Survey")
      journal6.createdDate = april30
      journal6.lastModified = april30
      for i in 1...28 {
          journal6.logs.append(Log(notes: "Pacific rim study \(i)"))
      }

      container.mainContext.insert(journal1)
      container.mainContext.insert(journal2)
      container.mainContext.insert(journal3)
      container.mainContext.insert(journal4)
      container.mainContext.insert(journal5)
      container.mainContext.insert(journal6)

      return DashboardView()
          .modelContainer(container)
  }

#Preview("Empty State") {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try! ModelContainer(for: Journal.self, Log.self, configurations: config)

      return DashboardView()
          .modelContainer(container)
  }
