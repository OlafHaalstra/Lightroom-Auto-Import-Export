-- Access the Lightroom SDK namespaces.
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

function getOS()
	-- ask LuaJIT first
	if jit then
		return jit.os
	end

	-- Unix, Linux variants
	local fh,err = assert(io.popen("uname -o 2>/dev/null","r"))
	if fh then
		osname = fh:read()
	end

	return osname or "Windows"
end

local operatingSystem = getOS()

local allowedExportSettings = {
	collisionHandling = "LR_collisionHandling",
	embeddedMetadataOption = "LR_embeddedMetadataOption",
	enableHDRDisplay = "LR_enableHDRDisplay",
	exportServiceProvider = "LR_exportServiceProvider",
	export_bitDepth = "LR_export_bitDepth",
	export_colorSpace = "LR_export_colorSpace",
	export_destinationPathSuffix = "LR_export_destinationPathSuffix",
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
	size_percentage = "LR_size_percentage",
	size_resolution = "LR_size_resolution",
	size_resolutionUnits = "LR_size_resolutionUnits",
	tokenCustomString = "LR_tokenCustomString",
	tokens = "LR_tokens",
	useWatermark = "LR_useWatermark",
	watermarking_id = "LR_watermarking_id",
}

-- Process pictures and save them as JPEG
local function processPhotos(photos, outputFolder, exportPreset)
	LrFunctionContext.callWithContext("export", function(exportContext)

		local progressScope = LrDialogs.showModalProgressDialog({
			title = "Auto applying presets",
			caption = "",
			cannotCancel = false,
			functionContext = exportContext
		})

		local exportSession = nil

		if exportPreset then
			-- After this operation the variable s exists with the presets
			(loadfile(exportPreset[1]))()
			local exportSettings = {
				LR_export_destinationPathPrefix = outputFolder,
				LR_export_destinationType = "specificFolder",
			}
			for key, value in pairs(s.value) do
				if allowedExportSettings[key] then
					exportSettings[allowedExportSettings[key]] = value
				end
			end

			exportSession = LrExportSession({
				photosToExport = photos,
				exportSettings = exportSettings
			})
			
		else
			exportSession = LrExportSession({
				photosToExport = photos,
				exportSettings = {
					LR_collisionHandling = "rename",
					LR_export_bitDepth = "8",
					LR_export_colorSpace = "sRGB",
					LR_export_destinationPathPrefix = outputFolder,
					LR_export_destinationType = "specificFolder",
					LR_export_useSubfolder = false,
					LR_format = "JPEG",
					LR_jpeg_quality = 1,
					LR_minimizeEmbeddedMetadata = true,
					LR_outputSharpeningOn = false,
					LR_reimportExportedPhoto = false,
					LR_renamingTokensOn = true,
					-- LR_size_doConstrain = true,
					LR_size_doNotEnlarge = true,
					-- LR_size_maxHeight = 1500,
					-- LR_size_maxWidth = 1500,
					LR_size_units = "pixels",
					LR_tokens = "{{image_name}}",
					LR_useWatermark = false,
				}
			})
		end

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
local function importFolder(LrCatalog, folder, outputFolder, processAll, exportPreset)
	local presetFolders = LrApplication.developPresetFolders()
	local presetFolder = presetFolders[1]
	local presets = presetFolder:getDevelopPresets()
	LrTasks.startAsyncTask(function()
		local photos = folder:getPhotos()
		local export = {}

		for _, photo in pairs(photos) do
			if (photo:getRawMetadata("rating") ~= 3 and (processAll or photo:getRawMetadata("pickStatus") == 1)) then
				LrCatalog:withWriteAccessDo("Apply Preset", function(context)
					for _, preset in pairs(presets) do
						photo:applyDevelopPreset(preset)
					end
					photo:setRawMetadata("rating", 3)
					table.insert(export, photo)
				end)
			end
		end

		if #export > 0 then
			processPhotos(export, outputFolder, exportPreset)
		end
	end)
end

-- GUI specification
local function customPicker()
	LrFunctionContext.callWithContext("showCustomDialogWithObserver", function(context)

		local props = LrBinding.makePropertyTable(context)
		local f = LrView.osFactory()

		local outputFolderField = f:edit_field {
			immediate = true,
			value = "D:\\Pictures"
		}

		local operatingSystem = getOS()
		local operatingSystemValue = f:static_text {
			title = operatingSystem
		}

		local numCharacters = 40
		local exportPreset = nil
		local watcherRunning = false

		local presetSelected = f:static_text {
			title = "Default",
			width_in_chars = numCharacters,
		}

		local staticTextValue = f:static_text {
			title = "Not started",
			width_in_chars = numCharacters,
		}

		local function myCalledFunction()
			staticTextValue.title = props.myObservedString
		end

		LrTasks.startAsyncTask(function()

			local LrCatalog = LrApplication.activeCatalog()
			local catalogFolders = LrCatalog:getFolders()
			local folderCombo = {}
			local folderIndex = {}
			for i, folder in pairs(catalogFolders) do
				folderCombo[i] = folder:getName()
				folderIndex[folder:getName()] = i
			end

			local folderField = f:combo_box {
				items = folderCombo
			}

			-- Watcher, executes function and then sleeps 60 seconds using PowerShell
			local function watch(processAll, exportPreset)
				local index = 0
				LrTasks.startAsyncTask(function()
					while watcherRunning do
						props.myObservedString = "Running - # runs: " .. index
						LrDialogs.showBezel("Processing images.")
						if catalogFolders[folderIndex[folderField.value]] then
							importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, processAll, exportPreset)
						else
							watcherRunning = false
							LrDialogs.message("No folder selected", "No folder selected, please select a folder in the dropdown and then click inside of the 'Output folder' field.")
						end
						if LrTasks.canYield() then
							LrTasks.yield()
						end
						if operatingSystem == "Windows" then
							LrTasks.execute("powershell Start-Sleep -Seconds 60")
						else
							LrTasks.execute("sleep 60")
						end
						index = index + 1
					end
				end)
			end

			props:addObserver("myObservedString", myCalledFunction)

			local c = f:column {
				spacing = f:dialog_spacing(),
				f:row {
					fill_horizontal = 1,
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Watcher running: "
					},
					staticTextValue,
				},
				f:row {
					fill_horizontal = 1,
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Operating system: "
					},
					operatingSystemValue,
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
							exportPreset = LrDialogs.runOpenPanel {
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
								presetSelected.title = string.sub(filename, filenameLength - numCharacters + 1, filenameLength)
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
					presetSelected,
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Select folder: "
					},
					folderField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Output folder: "
					},
					outputFolderField
				},
				f:row {
					f:column {
						spacing = f:dialog_spacing(),
						f:push_button {
							title = "Process flagged",

							action = function()
								if folderField.value ~= "" then
									props.myObservedString = "Working"
									importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, false, exportPreset)
									props.myObservedString = "Processed once"
								else
									LrDialogs.message("Please select an input folder")
								end
							end
						},
						f:push_button {
							title = "Process all",

							action = function()
								if folderField.value ~= "" then
									props.myObservedString = "Working"
									importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, true, exportPreset)
									props.myObservedString = "Processed once"
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
								if folderField.value ~= "" then
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
								if folderField.value ~= "" then
									props.myObservedString = "Running"
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
							props.myObservedString = "Stopped after running"
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
