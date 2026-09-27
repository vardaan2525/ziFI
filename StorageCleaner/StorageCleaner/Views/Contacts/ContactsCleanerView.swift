import SwiftUI
import Contacts

public struct ContactsCleanerView: View {
    @ObservedObject var contactsManager = ContactsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ContactsTab = .duplicates
    @State private var isMergingAll: Bool = false
    @State private var showMergeSuccessAlert: Bool = false
    @State private var mergedCount: Int = 0
    @State private var selectedMissingIds: Set<String> = []
    
    enum ContactsTab: String, CaseIterable {
        case duplicates = "Duplicates"
        case missingInfo = "Incomplete"
    }
    
    public init() {}
    
    private var allDuplicateGroups: [DuplicateContactGroup] {
        contactsManager.duplicateNameGroups + contactsManager.duplicatePhoneGroups
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground.ignoresSafeArea()
                
                if contactsManager.authStatus != .authorized {
                    permissionView
                } else if contactsManager.isLoading {
                    loadingView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("Contacts Cleanup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        HapticManager.selection()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.appleBlue)
                }
                
                if contactsManager.authStatus == .authorized && !allDuplicateGroups.isEmpty && selectedTab == .duplicates {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                isMergingAll = true
                                let count = await contactsManager.mergeAllDuplicates()
                                mergedCount = count
                                isMergingAll = false
                                showMergeSuccessAlert = true
                            }
                        }) {
                            if isMergingAll {
                                ProgressView().tint(.cyan)
                            } else {
                                Text("Merge All")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.cyanAccent)
                            }
                        }
                        .disabled(isMergingAll)
                    }
                }
            }
            .alert("Contacts Merged", isPresented: $showMergeSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Successfully merged \(mergedCount) duplicate contact groups into clean unified contacts.")
            }
            .task {
                if contactsManager.authStatus == .authorized {
                    await contactsManager.scanContacts()
                }
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Stats Header
            headerStats
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Tab Selector
            tabSelector
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Content
            if selectedTab == .duplicates {
                if allDuplicateGroups.isEmpty {
                    emptyDuplicatesView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(allDuplicateGroups) { group in
                                duplicateGroupCard(group: group)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 60)
                    }
                }
            } else {
                if contactsManager.missingInfoContacts.isEmpty {
                    emptyMissingView
                } else {
                    missingInfoListView
                }
            }
        }
    }
    
    // MARK: - Header Stats
    private var headerStats: some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(contactsManager.allContacts.count)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("Total")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 24).background(Color.white.opacity(0.1))
                
                VStack(spacing: 2) {
                    Text("\(contactsManager.totalDuplicatesCount)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(contactsManager.totalDuplicatesCount > 0 ? Color.orange : Color.green)
                    Text("Duplicates")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 24).background(Color.white.opacity(0.1))
                
                VStack(spacing: 2) {
                    Text("\(contactsManager.missingInfoContacts.count)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Incomplete")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(ContactsTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticManager.selection()
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selectedTab == tab ? .white : AppTheme.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                        )
                }
            }
            Spacer()
        }
    }
    
    // MARK: - Duplicate Group Card
    private func duplicateGroupCard(group: DuplicateContactGroup) -> some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(group.contacts.count) duplicate entries • \(group.reason.rawValue)")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            _ = await contactsManager.mergeGroup(group)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 11, weight: .bold))
                            Text("Merge")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                // Contact entries
                VStack(spacing: 6) {
                    ForEach(group.contacts) { contact in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(String(contact.fullName.prefix(1)).uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.fullName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                
                                if let phone = contact.phoneNumbers.first {
                                    Text(phone)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                } else if let email = contact.emailAddresses.first {
                                    Text(email)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(14)
        }
    }
    
    // MARK: - Missing Info List View
    private var missingInfoListView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(contactsManager.missingInfoContacts) { contact in
                        let isSelected = selectedMissingIds.contains(contact.id)
                        
                        Button(action: {
                            HapticManager.selection()
                            if isSelected {
                                selectedMissingIds.remove(contact.id)
                            } else {
                                selectedMissingIds.insert(contact.id)
                            }
                        }) {
                            GlassCard(cornerRadius: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(isSelected ? .cyan : AppTheme.textMuted)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.fullName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        Text("No phone or email saved")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.textMuted)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
            
            if !selectedMissingIds.isEmpty {
                VStack {
                    Button(action: {
                        Task {
                            _ = await contactsManager.deleteContacts(ids: Array(selectedMissingIds))
                            selectedMissingIds.removeAll()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("Delete \(selectedMissingIds.count) Incomplete Contacts")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.85)))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(hex: "0D111A"))
            }
        }
    }
    
    // MARK: - Empty States
    private var emptyDuplicatesView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("No Duplicate Contacts")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Your contact book is neat and clean with zero duplicate entries.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    private var emptyMissingView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 52))
                .foregroundColor(.cyan)
            Text("All Contacts Complete")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("All contacts in your address book have valid phone numbers or email addresses.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    // MARK: - Permission Prompt
    private var permissionView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 56))
                .foregroundColor(.cyan)
            
            VStack(spacing: 8) {
                Text("Contacts Access")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                Text("ziFI needs contacts access to safely scan and merge duplicate names and phone numbers on-device.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            
            Button(action: {
                Task {
                    _ = await contactsManager.requestAccess()
                }
            }) {
                Text("Allow Contacts Access")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: 260)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white)
            Text("Scanning address book for duplicates...")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}
