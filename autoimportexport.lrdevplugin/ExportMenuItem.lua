-- Access the Lightroom SDK namespaces.
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

local allowedExportSettings = {
	collisionHandling = "LR_collisionHandling",
	contentCredentials_include_connectedAccounts = "LR_contentCredentials_include_connectedAccounts",
	contentCredentials_include_editsAndActivity = "LR_contentCredentials_include_editsAndActivity",
	contentCredentials_include_producer = "LR_contentCredentials_include_producer",
	contentCredentials_include_status = "LR_contentCredentials_include_status",
	embeddedMetadataOption = "LR_embeddedMetadataOption",
	enableHDRDisplay = "LR_enableHDRDisplay",
	exportServiceProvider = "LR_exportServiceProvider",
	exportServiceProviderTitle = "LR_exportServiceProviderTitle",
	export_bitDepth = "LR_export_bitDepth",
	export_colorSpace = "LR_export_colorSpace",
	export_destinationPathPrefix = "LR_export_destinationPathPrefix",
	export_destinationPathSuffix = "LR_export_destinationPathSuffix",
	export_destinationType = "LR_export_destinationType",
	export_postProcessing = "LR_export_postProcessing",
	export_useParentFolder = "LR_export_useParentFolder",
	export_useSubfolder = "LR_export_useSubfolder",
	export_videoFileHandling = "LR_export_videoFileHandling",
	export_videoFormat = "LR_export_videoFormat",
	export_videoPreset = "LR_export_videoPreset",
	extensionCase = "LR_extensionCase",
	format = "LR_format",
	includeFaceTagsAsKeywords = "LR_includeFaceTagsAsKeywords",
	includeFaceTagsInIptc = "LR_includeFaceTagsInIptc",
	includeVideoFiles = "LR_includeVideoFiles",
	initialSequenceNumber = "LR_initialSequenceNumber",
	jpeg_limitSize = "LR_jpeg_limitSize",
	jpeg_quality = "LR_jpeg_quality",
	jpeg_useLimitSize = "LR_jpeg_useLimitSize",
	markedPresets = "LR_markedPresets",
	maximumCompatibility = "LR_maximumCompatibility",
	metadata_keywordOptions = "LR_metadata_keywordOptions",
	outputSharpeningLevel = "LR_outputSharpeningLevel",
	outputSharpeningMedia = "LR_outputSharpeningMedia",
	outputSharpeningOn = "LR_outputSharpeningOn",
	reimportExportedPhoto = "LR_reimportExportedPhoto",
	reimport_stackWithOriginal = "LR_reimport_stackWithOriginal",
	reimport_stackWithOriginal_position = "LR_reimport_stackWithOriginal_position",
	removeFaceMetadata = "LR_removeFaceMetadata",
	removeLocationMetadata = "LR_removeLocationMetadata",
	renamingTokensOn = "LR_renamingTokensOn",
	selectedTextFontFamily = "LR_selectedTextFontFamily",
	selectedTextFontSize = "LR_selectedTextFontSize",
	size_doConstrain = "LR_size_doConstrain",
	size_doNotEnlarge = "LR_size_doNotEnlarge",
	size_maxHeight = "LR_size_maxHeight",
	size_maxWidth = "LR_size_maxWidth",
	size_percentage = "LR_size_percentage",
	size_resizeType = "LR_size_resizeType",
	size_resolution = "LR_size_resolution",
	size_resolutionUnits = "LR_size_resolutionUnits",
	size_units = "LR_size_units",
	size_userWantsConstrain = "LR_size_userWantsConstrain",
	tokenCustomString = "LR_tokenCustomString",
	tokens = "LR_tokens",
	tokensArchivedToString2 = "LR_tokensArchivedToString2",
	useWatermark = "LR_useWatermark",
	watermarking_id = "LR_watermarking_id",
}

local function parsePreset(exportPreset)
	-- After this operation the variable s exists with the presets
	(loadfile(exportPreset[1]))()

	local exportSettings = {}

	for key, value in pairs(s.value) do
		if allowedExportSettings[key] then
			exportSettings[allowedExportSettings[key]] = value
		end
	end

	return exportSettings
end

-- Process pictures and save them as JPEG
local function processPhotos(photos, exportSettings)
	LrFunctionContext.callWithContext("export", function(exportContext)

		local progressScope = LrDialogs.showModalProgressDialog({
			title = "Auto applying presets",
			caption = "",
			cannotCancel = false,
			functionContext = exportContext
		})

		local exportSession = LrExportSession({
			photosToExport = photos,
			exportSettings = exportSettings
		})

		local numPhotos = exportSession:countRenditions()

		local renditionParams = {
			progressScope = progressScope,
			renderProgressPortion = 1,
			stopIfCanceled = true,
		}

		for i, rendition in exportSession:renditions(renditionParams) do

			-- Stop processing if the cancel button has been pressed
			if progressScope:isCanceled() then
				break
			end

			-- Common caption for progress bar
			local progressCaption = rendition.photo:getFormattedMetadata("fileName") .. " (" .. i .. "/" .. numPhotos .. ")"

			progressScope:setPortionComplete(i - 1, numPhotos)
			progressScope:setCaption("Processing " .. progressCaption)

			rendition:waitForRender()
		end
	end)
end

-- Import pictures from folder where the rating is not 3 stars and the photo is flagged.
local function importFolder(LrCatalog, folder, processAll, exportSettings)
	local presetFolders = LrApplication.developPresetFolders()
	local presetFolder = presetFolders[1]
	local presets = presetFolder:getDevelopPresets()
	LrTasks.startAsyncTask(function()
		local photos = folder:getPhotos()
		local export = {}

		for _, photo in pairs(photos) do
			if (photo:getRawMetadata("rating") ~= 3 and (processAll or photo:getRawMetadata("pickStatus") == 1)) then
				LrCatalog:withWriteAccessDo("Apply Preset", (function(context)
					for _, preset in pairs(presets) do
						photo:applyDevelopPreset(preset)
						-- Tiny sleep in order to succesfully apply the preset
						LrTasks.sleep(0.1)
					end
					photo:setRawMetadata("rating", 3)
					table.insert(export, photo)
				end),
				{timeout = 30})
			end
		end

		LrTasks.sleep(1)

		if #export > 0 then
			processPhotos(export, exportSettings)
		end
	end)
end

-- GUI specification
local function customPicker()
	LrFunctionContext.callWithContext("showCustomDialogWithObserver", function(context)

		local props = LrBinding.makePropertyTable(context)
		local f = LrView.osFactory()

		local operatingSystem = ""
		local seperator = ""

		local homePath = LrPathUtils.getStandardFilePath("home")

		if string.find(homePath, "\\") then
			operatingSystem = "Windows"
			seperator = "\\"
		else
			operatingSystem = "MacOS"
			seperator = "/"
		end

		props.watcherStatus = "Not started"
		props.selectedLightroomFolder = ""
		props.outputFolderPath = homePath .. seperator .. "Downloads"

		props.presetSelected = "Default"
		props.exportSettings = {
			LR_collisionHandling = "rename",
			LR_export_bitDepth = "8",
			LR_export_colorSpace = "sRGB",
			LR_export_destinationPathPrefix = props.outputFolderPath,
			LR_export_destinationType = "specificFolder",
			LR_export_useSubfolder = false,
			LR_format = "JPEG",
			LR_jpeg_quality = 1,
			LR_minimizeEmbeddedMetadata = true,
			LR_outputSharpeningOn = false,
			LR_reimportExportedPhoto = false,
			LR_renamingTokensOn = true,
			LR_size_doNotEnlarge = true,
			LR_size_units = "pixels",
			LR_tokens = "{{image_name}}",
			LR_useWatermark = false,
		}

		local numCharacters = 40
		local watcherRunning = false

		LrTasks.startAsyncTask(function()

			local LrCatalog = LrApplication.activeCatalog()
			local catalogFolders = LrCatalog:getFolders()
			local folderCombo = {}
			local folderIndex = {}
			for i, folder in pairs(catalogFolders) do
				folderCombo[i] = folder:getName()
				folderIndex[folder:getName()] = i
			end

			props.folderField = f:combo_box {
				value = LrView.bind("selectedLightroomFolder"),
				items = folderCombo
			}

			-- Watcher, executes function and then sleeps 60 seconds using PowerShell
			local function watch(processAll)
				local index = 0
				LrTasks.startAsyncTask(function()
					while watcherRunning do
						props.watcherStatus = "Running - # runs: " .. index
						LrDialogs.showBezel("Processing images.")
						if catalogFolders[folderIndex[props.folderField.value]] then
							importFolder(LrCatalog, catalogFolders[folderIndex[props.folderField.value]], processAll, props.exportSettings)
						else
							watcherRunning = false
							LrDialogs.message("No folder selected", "No folder selected, please select a folder in the dropdown and then click inside of the 'Output folder' field.")
						end
						if LrTasks.canYield() then
							LrTasks.yield()
						end
						LrTasks.sleep(3)
					end
				end)
			end

			local c = f:column {
				bind_to_object = props,
				spacing = f:dialog_spacing(),
				f:row {
					fill_horizontal = 1,
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Watcher running: "
					},
					f:static_text {
						width_in_chars = numCharacters,
						title = LrView.bind("watcherStatus")
					},
				},
				f:row {
					fill_horizontal = 1,
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Operating system: "
					},
					f:static_text {
						title = operatingSystem
					},
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Lightroom folder: "
					},
					props.folderField
				},
				f:row {
					f:static_text {
						title = "Please press 'Tab' after selecting the Lightroom folder"
					},
				},
				f:row {
					fill_horizontal = 1,
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Select export preset:"
					},
					f:push_button {
						title = "Select",
						action = function()
							local exportPreset = LrDialogs.runOpenPanel {
								title = "Select Export Settings",
								canChooseFiles = true,
								canChooseDirectories = false,
								canCreateDirectories = false,
								allowedFileTypes = {'lrtemplate', 'xmp'},
								multipleSelection = false,
							}
							if exportPreset then
								local filename = exportPreset[1]
								local filenameLength = #filename
								props.presetSelected = string.sub(filename, filenameLength - numCharacters + 1, filenameLength)
							end
							props.exportSettings = parsePreset(exportPreset)
							if props.exportSettings["LR_export_destinationPathPrefix"] then
								props.outputFolderPath = props.exportSettings["LR_export_destinationPathPrefix"]
							end			
						end
					},
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Preset selected:"
					},
					f:static_text {
						width_in_chars = numCharacters,
						title = LrView.bind("presetSelected")
					},
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Export folder: "
					},
					f:push_button {
						title = "Select export Folder",
						action = function()
							exportFolder = LrDialogs.runOpenPanel {
								title = "Select Export Settings",
								canChooseFiles = false,
								canChooseDirectories = true,
								canCreateDirectories = true,
								multipleSelection = false,
							}
							if exportFolder then
								props.outputFolderPath = exportFolder[1]
							end
						end
					},
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Export folder selected:"
					},
					f:static_text {
						width_in_chars = numCharacters,
						title = LrView.bind( {
							keys = { "outputFolderPath", "exportSettings" },
							transform = function()
								props.exportSettings["LR_export_destinationPathPrefix"] = props.outputFolderPath
								if props.exportSettings["LR_export_destinationPathSuffix"] then
									return props.exportSettings["LR_export_destinationPathPrefix"] .. seperator .. props.exportSettings["LR_export_destinationPathSuffix"]
								else
									return props.exportSettings["LR_export_destinationPathPrefix"]
								end
							end	
						})
					}
				},
				f:row {
					f:column {
						spacing = f:dialog_spacing(),
						f:push_button {
							title = "Process flagged",

							action = function()
								if props.folderField.value ~= "" then
									props.watcherStatus = "Working"
									importFolder(LrCatalog, catalogFolders[folderIndex[props.folderField.value]], false, props.exportSettings)
									props.watcherStatus = "Processed once"
								else
									LrDialogs.message("Please select an input folder")
								end
							end
						},
						f:push_button {
							title = "Process all",

							action = function()
								if props.folderField.value ~= "" then
									props.watcherStatus = "Working"
									importFolder(LrCatalog, catalogFolders[folderIndex[props.folderField.value]], true, props.exportSettings)
									props.watcherStatus = "Processed once"
								else
									LrDialogs.message("Please select an input folder")
								end
							end
						},
					},
					f:column {
						spacing = f:dialog_spacing(),
						f:push_button {
							title = "Watch flagged",

							action = function()
								watcherRunning = true
								if props.folderField.value ~= "" then
									watch(false)
								else
									LrDialogs.message("Please select an input folder")
								end
							end
						},
						f:push_button {
							title = "Watch all",

							action = function()
								watcherRunning = true
								if props.folderField.value ~= "" then
									props.watcherStatus = "Running"
									watch(true)
								else
									LrDialogs.message("Please select an input folder")
								end
							end
						},
					},
					f:push_button {
						title = "Pause watcher",

						action = function()
							watcherRunning = false
							props.watcherStatus = "Stopped after running"
						end
					},
				}
			}

			LrDialogs.presentModalDialog {
				title = "Auto Edit Watcher",
				contents = c,
				buttons = {
					{ title = "Cancel", action = function() watcherRunning = false end },
					{ title = "Run in background", },
				},			   
			}

		end)

	end)
end

customPicker()
