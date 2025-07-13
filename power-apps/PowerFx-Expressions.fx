// ==============================================
// SentinelLog PowerFx Expressions
// ==============================================

// ------ FILENAME BUILDER MODULE ------
// Generates filename using Context-Function-Dependency-Iteration-Flag pattern
// Example: 300007001002P01.txt
GenerateFileName = 
    Concatenate(
        ContextCodeDropdown.Selected.ID,
        FunctionCodeDropdown.Selected.ID,
        DependencyCodeDropdown.Selected.ID,
        IterationCodeDropdown.Selected.ID,
        If(IsBlank(FlagCodeDropdown.Selected.ID), "", FlagCodeDropdown.Selected.ID),
        If(IsBlank(IterationCodeDropdown.Selected.ID), "01", Right("00" & IterationCodeDropdown.Selected.ID, 2)),
        ".",
        FileExtensionDropdown.Selected.ID
    )

// ------ TRANSCRIPT FORMATTER MODULE ------
// Formats chat transcript with timestamp header and footer
FormatTranscript = 
    Concatenate(
        "=== SENTINELLOG CHAT TRANSCRIPT ===", Char(10),
        "Generated: ", Text(Now(), "yyyy-mm-dd hh:mm:ss UTC"), Char(10),
        "User: ", User().FullName, Char(10),
        "Email: ", User().Email, Char(10),
        "File: ", GeneratedFileName, Char(10),
        "Description: ", DescriptionInput.Text, Char(10),
        "Context: ", ContextCodeDropdown.Selected.Value, Char(10),
        "Function: ", FunctionCodeDropdown.Selected.Value, Char(10),
        "Dependency: ", DependencyCodeDropdown.Selected.Value, Char(10),
        "Iteration: ", IterationCodeDropdown.Selected.Value, Char(10),
        If(IsBlank(FlagCodeDropdown.Selected.Value), "", "Flag: " & FlagCodeDropdown.Selected.Value & Char(10)),
        "=" & Concatenate(Table({a:1},{a:2},{a:3},{a:4},{a:5},{a:6},{a:7},{a:8},{a:9},{a:10},{a:11},{a:12},{a:13},{a:14},{a:15},{a:16},{a:17},{a:18},{a:19},{a:20},{a:21},{a:22},{a:23},{a:24},{a:25},{a:26},{a:27},{a:28},{a:29},{a:30},{a:31},{a:32},{a:33},{a:34},{a:35},{a:36},{a:37},{a:38},{a:39},{a:40}), "="), Char(10),
        Char(10),
        "CONVERSATION START", Char(10),
        Char(10),
        ChatTranscriptInput.Text,
        Char(10),
        Char(10),
        "CONVERSATION END", Char(10),
        Char(10),
        "=== END OF TRANSCRIPT ===", Char(10),
        "Archive Date: ", Text(Now(), "yyyy-mm-dd hh:mm:ss UTC"), Char(10),
        "Compliance: Document Control Standards Applied", Char(10),
        "Version: 1.0", Char(10),
        "System: SentinelLog v1.0"
    )

// ------ SHAREPOINT PATH BUILDER ------
// Creates dynamic SharePoint folder path based on context and function
BuildSharePointPath = 
    Concatenate(
        "/Shared Documents/ChatGPT-Logs/",
        ContextCodeDropdown.Selected.Value, "/",
        FunctionCodeDropdown.Selected.Value, "/",
        DependencyCodeDropdown.Selected.Value, "/"
    )

// ------ DATA VALIDATION MODULE ------
// Validates all required fields before submission
ValidateInputs = 
    And(
        Not(IsBlank(ChatTranscriptInput.Text)),
        Not(IsBlank(ContextCodeDropdown.Selected.ID)),
        Not(IsBlank(FunctionCodeDropdown.Selected.ID)),
        Not(IsBlank(DependencyCodeDropdown.Selected.ID)),
        Not(IsBlank(IterationCodeDropdown.Selected.ID)),
        Not(IsBlank(FileExtensionDropdown.Selected.ID)),
        Len(ChatTranscriptInput.Text) > 10
    )

// ------ SUBMIT FUNCTION ------
// Main submit function that triggers Power Automate flow
SubmitChatLog = 
    If(
        ValidateInputs,
        // Valid inputs - proceed with submission
        Concurrent(
            // Set loading state
            Set(IsSubmitting, true),
            
            // Generate filename
            Set(GeneratedFileName, GenerateFileName),
            
            // Prepare data for Power Automate
            Set(SubmissionData, {
                chatTranscript: FormatTranscript,
                fileName: GeneratedFileName,
                sharePointPath: BuildSharePointPath,
                contextCode: ContextCodeDropdown.Selected.ID,
                functionCode: FunctionCodeDropdown.Selected.ID,
                dependencyCode: DependencyCodeDropdown.Selected.ID,
                iterationCode: IterationCodeDropdown.Selected.ID,
                flagCode: If(IsBlank(FlagCodeDropdown.Selected.ID), "", FlagCodeDropdown.Selected.ID),
                fileExtension: FileExtensionDropdown.Selected.ID,
                description: DescriptionInput.Text,
                userEmail: User().Email,
                userFullName: User().FullName,
                timestamp: Text(Now(), "yyyy-mm-dd hh:mm:ss UTC"),
                contextName: ContextCodeDropdown.Selected.Value,
                functionName: FunctionCodeDropdown.Selected.Value,
                dependencyName: DependencyCodeDropdown.Selected.Value,
                iterationName: IterationCodeDropdown.Selected.Value,
                flagName: If(IsBlank(FlagCodeDropdown.Selected.Value), "", FlagCodeDropdown.Selected.Value)
            }),
            
            // Call Power Automate flow
            Set(FlowResult, 
                PowerAutomate.Run(
                    "ProcessChatLogSubmission",
                    SubmissionData
                )
            ),
            
            // Handle response
            If(
                FlowResult.success,
                Concurrent(
                    Set(SharePointFileURL, FlowResult.fileUrl),
                    Set(IsSubmitting, false),
                    // Add to recent uploads
                    Set(RecentUploads, 
                        FirstN(
                            Ungroup(
                                Table({
                                    FileName: GeneratedFileName,
                                    Timestamp: Text(Now(), "mm/dd/yyyy hh:mm"),
                                    FileURL: SharePointFileURL,
                                    Description: DescriptionInput.Text
                                }),
                                "Value"
                            ) & RecentUploads,
                            10
                        )
                    ),
                    // Navigate to success screen
                    Navigate(SuccessScreen, ScreenTransition.Fade)
                ),
                // Handle error
                Concurrent(
                    Set(IsSubmitting, false),
                    Set(ErrorMessage, "Submission failed: " & FlowResult.error),
                    Notify(ErrorMessage, NotificationType.Error)
                )
            )
        ),
        // Invalid inputs - show error
        Notify("Please fill in all required fields and ensure chat transcript is valid", NotificationType.Warning)
    )

// ------ INITIALIZATION (OnStart) ------
// App initialization logic
OnStart = 
    Concurrent(
        // Initialize variables
        Set(IsSubmitting, false),
        Set(GeneratedFileName, ""),
        Set(SharePointFileURL, ""),
        Set(ErrorMessage, ""),
        Set(CurrentUser, User()),
        
        // Load recent uploads from SharePoint or local storage
        Set(RecentUploads, []),
        
        // Set default values
        Set(ContextCodeDropdown, {ID: "300", Value: "Production"}),
        Set(FileExtensionDropdown, {ID: "txt", Value: "Text (.txt)"}),
        Set(IterationCodeDropdown, {ID: "001", Value: "Initial"})
    )

// ------ UTILITY FUNCTIONS ------
// Clear form after successful submission
ClearForm = 
    Concurrent(
        Reset(ChatTranscriptInput),
        Reset(ContextCodeDropdown),
        Reset(FunctionCodeDropdown),
        Reset(DependencyCodeDropdown),
        Reset(IterationCodeDropdown),
        Reset(FlagCodeDropdown),
        Reset(DescriptionInput),
        Set(GeneratedFileName, ""),
        Set(SharePointFileURL, "")
    )

// Real-time filename preview
PreviewFileName = 
    If(
        And(
            Not(IsBlank(ContextCodeDropdown.Selected.ID)),
            Not(IsBlank(FunctionCodeDropdown.Selected.ID)),
            Not(IsBlank(DependencyCodeDropdown.Selected.ID))
        ),
        Concatenate(
            ContextCodeDropdown.Selected.ID,
            FunctionCodeDropdown.Selected.ID,
            DependencyCodeDropdown.Selected.ID,
            If(IsBlank(IterationCodeDropdown.Selected.ID), "001", Right("00" & IterationCodeDropdown.Selected.ID, 3)),
            If(IsBlank(FlagCodeDropdown.Selected.ID), "", FlagCodeDropdown.Selected.ID),
            ".",
            If(IsBlank(FileExtensionDropdown.Selected.ID), "txt", FileExtensionDropdown.Selected.ID)
        ),
        "Please select required fields..."
    )

// ------ SUBMIT BUTTON PROPERTIES ------
SubmitButton.DisplayMode = If(ValidateInputs && !IsSubmitting, DisplayMode.Edit, DisplayMode.Disabled)
SubmitButton.Text = If(IsSubmitting, "Submitting...", "Submit Chat Log")

// ------ REAL-TIME VALIDATION FEEDBACK ------
ValidationMessage = 
    If(
        IsBlank(ChatTranscriptInput.Text),
        "Chat transcript is required",
        If(
            Len(ChatTranscriptInput.Text) <= 10,
            "Chat transcript must be longer than 10 characters",
            If(
                Or(
                    IsBlank(ContextCodeDropdown.Selected.ID),
                    IsBlank(FunctionCodeDropdown.Selected.ID),
                    IsBlank(DependencyCodeDropdown.Selected.ID)
                ),
                "Please select all required dropdown fields",
                "✓ All fields validated - ready to submit"
            )
        )
    )