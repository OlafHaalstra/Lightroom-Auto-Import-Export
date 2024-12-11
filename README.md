# Auto Import Export

_Auto import export for Lightroom which applies all favorite presets_

Easily edit (flagged) photos with a set of presets, convenient for events where you continuously want to output your pictures.

## Installation

1. Clone this repository or download the folder to your disk.
2. Add the plugin by adding the folder in Lightroom via `File > Plug-in Manager` or press `Ctrl+Alt+Shift+,`
   ![Plug-in Manager](images/2022-07-24-15-24-19.png)
   
## Usage

1. Prepare your presets in the favorites folder. For convenience you can create a preset that first applies `Auto Settings` and then another preset to create the look and feel you want to have. For example you can set it up like this:

   ![Favorite Presets](images/2022-07-24-15-29-30.png)

1. (Optional) Flag all photos you want to apply the filter to and export as `Flagged`.

1. Open the `Auto Import Export` window by navigating to `File > Plug-in Extras > Auto Import Export`.

   ![Auto Import Export](<images/auto-import-export.png>)

1. Specify which Lightroom folder you want to apply the script to. 

   **IMPORTANT**: Make sure to press "Tab" after selecting the folder from the dropdown, otherwise this will not propagate. 

1. (Optional) Select an export preset.

1. (Optional) Change the export location (default: `~/Downloads`)

1. Basically there are two options:
   
   (A) `Process flagged/all` apply the script once to the pictures in the folder 
   
   (B) `Watch flagged/all` that will run the script every 60 seconds

1. This will process all pictures by:

   - Applying the presets in the favorite folder (top to bottom) that have are flagged (or all when `all` is selected)
   - Rating the picture with 3 stars to keep track which pictures do not need to be processed again
   - Exporting full quality JPEG to the specified folder (or based on custom settings when a custom export preset is selected)

1. Press pause watcher if you want to stop the watcher. If you want to run the script in the background press `OK` or `Cancel`. 

   _Note: that it will keep on running as long as Lightroom is open (a more neat solution is yet to be found)._

1. Enjoy your edited photos without lifting a single finger!

## Improvements

If you have any suggestions for improvements feel free to open a pull request or creating an issue.

**Whishlist**

- Change functionality of `OK` and `Cancel` buttons to run the script in the background or stop it.
