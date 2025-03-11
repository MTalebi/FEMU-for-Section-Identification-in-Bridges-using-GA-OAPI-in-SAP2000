# FEMU for Section Identification in Bridges Using GA-OAPI in SAP2000

**Author:**  
**Mohammad Talebi-Kalaleh**

**GitHub Repository:**  
[https://github.com/MTalebi/FEMU-for-Section-Identification-in-Bridges-using-GA-OAPI-in-SAP2000/tree/main](https://github.com/MTalebi/FEMU-for-Section-Identification-in-Bridges-using-GA-OAPI-in-SAP2000/tree/main)

**Publish Date:**  
July 7, 2022

---

## Overview

This documentation details a **Finite Element Model Updating (FEMU)** approach for **Section Identification** in bridge structures by leveraging the **SAP2000** Open Application Programming Interface (**OAPI**) and a **Genetic Algorithm (GA)**. The main objective is to match the simulated time-history response (in this case, Z-direction accelerations) with measured data from a real or simulated bridge, by systematically adjusting section dimensions (e.g., flange width, flange thickness, web height, and web thickness).

A high-level summary of the workflow:

1. **Main Script**  
   - Sets up the MATLAB environment and retrieves user-selected `.sdb` (SAP2000 model) and `.txt` (measured data) files.  
   - Gathers and classifies frames, grouping them by their auto-select section property names.  
   - Extracts dimension ranges for each group (flange width/thickness, web height/thickness) from the model’s “Notes” in SAP2000 properties.  
   - Configures and runs the GA to optimize these section dimensions.  
   - Retrieves analysis results from SAP2000, then plots simulated vs. measured accelerations.

2. **Objective_Fun.m**  
   - Updates the **I-section** properties in SAP2000 (using the `SetISection` method) based on the GA’s trial solutions.  
   - Runs the SAP2000 analysis.  
   - Compares the resulting accelerations against measured data, returning a cost (error) to be minimized.

---

## Main Script Explanation

1. **Initialization and Input Files**  
   - The script clears the MATLAB workspace and prompts the user for a **SAP2000** `.sdb` file and a **measured data** directory via `uigetfile`.  
   - Paths for the SAP2000 executable and DLL are stored for reference.

2. **SAP2000 OAPI Creation**  
   - Loads the `.NET` assembly for SAP2000 OAPI.  
   - Acquires an instance of the `SapObject` and thus the main `SapModel`.  
   - Extracts interface objects for frames, loads, analysis, etc.

3. **Model Handling**  
   - Saves the current model under a new name (prefixed by `"Identified_"`).  
   - Unlocks the model to allow changes and switches to a specific unit system (`kgf_cm_C`).

4. **Frame Grouping and Autoselect Sections**  
   - Retrieves the list of all frames using `FrameObj.GetNameList`.  
   - For each frame, it gets the assigned **auto-select** name (i.e., the property that can vary among multiple dimension options).  
   - Sorts and groups frames by their auto-select property names.  
   - Creates a SAP2000 group for each auto-select section to facilitate bulk modifications in the next steps.

5. **Reading Section Dimensions from Notes**  
   - For each **auto-select** name, the script fetches the initial I-section dimensions using `PropFrame.GetISection`.  
   - Captures the “Notes” string for each property, where dimension arrays (e.g., `FlangeWidth=[25,30,35]`) are stored.  
   - Uses `eval` on each line from the notes to load dimension arrays into the workspace.  
   - Saves these dimension sets (for flange width/thickness, web height/thickness) in a structure `Autoselect_Name_Sections` for reference.

6. **Defining GA Variables and Bounds**  
   - Each group corresponds to **4 integer variables**:  
     1. Index of **FlangeWidth**  
     2. Index of **FlangeThickness**  
     3. Index of **WebHeight**  
     4. Index of **WebThickness**  
   - If `UseAllDimsInAutoListMembers` = “Yes”, the GA may use the full range of each dimension array. Otherwise, the script imposes a limited range around the initial section index.  
   - Constructs **lower** (`lb`) and **upper** (`ub`) integer bounds accordingly.  
   - An **initial solution** (`x0`) is built from the as-is section index for each dimension parameter.

7. **GA Configuration**  
   - Sets up the objective function `fun` to point to `Objective_Fun`.  
   - Chooses GA options (generations, population size, etc.).  
   - Specifies integer constraints (`IntCon`) for all variables, ensuring they remain integer indices within dimension arrays.  
   - Runs the GA (`ga(fun, nvars, [], [], [], [], lb, ub, [], IntCon, options)`).

8. **Analysis Case Setup**  
   - Selects the relevant time-history load case (`TH_LoadCase_Name` = “RHA Moveing Load”).  
   - Deselects other analysis cases to focus on the required output.  
   - Ensures the correct output options for direct-history results in the Z-direction.

9. **Reading and Plotting Sensor Data**  
   - The script reads measured accelerations from `.txt` files for each sensor point in `Output_Sensor_Joints`.  
   - After the GA finishes, it extracts the final acceleration results from SAP2000 and compares them with the measured data.  
   - Plots Z-acceleration time histories for a visual check of the model’s performance.

---

## Objective_Fun.m

This function defines the cost metric for the GA. Key steps include:

1. **Updating I-Sections in SAP2000**  
   - For each group, retrieve the **bf**, **tf**, **hw**, and **tw** dimension values corresponding to the integer indices in `x`.  
   - Call `PropFrame.SetISection` to update the geometry in SAP2000.

2. **Analysis and Results Extraction**  
   - Run the SAP2000 analysis with `Analyze.RunAnalysis`.  
   - Query the resulting acceleration in the Z-direction from `AnalysisResults.JointAcc`.

3. **Computing the Cost**  
   - For each sensor point, the measured acceleration is interpolated onto the SAP2000 analysis time steps.  
   - The difference (norm) between measured and simulated data is summed across all sensors and time points.  
   - The cost is then normalized (divided by the number of sensors and time points) and returned to the GA.

---

## How to Cite

If you find this code or methodology useful in your research or projects, please cite:

> **Talebi-Kalaleh, Mohammad.** (2022). *FEMU for Section Identification in Bridges using GA and OAPI in SAP2000.* Published July 7, 2022. GitHub repository: [https://github.com/MTalebi/FEMU-for-Section-Identification-in-Bridges-using-GA-OAPI-in-SAP2000/tree/main](https://github.com/MTalebi/FEMU-for-Section-Identification-in-Bridges-using-GA-OAPI-in-SAP2000/tree/main)

---

## Notes and Extensions

1. **Requirements**  
   - SAP2000 v23 (or compatible version) with OAPI enabled.  
   - MATLAB with Optimization Toolbox (for GA).  
   - Corresponding `.sdb` and `.txt` measurement files.

2. **Usage**  
   - Run the main script in MATLAB.  
   - When prompted, select the `.sdb` file and the directory containing sensor `.txt` files.  
   - The script will create a new “Identified_” model file, run the GA, then plot and display final errors.

3. **Possible Extensions**  
   - Incorporate other structural elements or advanced section shapes with additional parameters.  
   - Enhance the objective function to account for other dynamic outputs (e.g., displacement or frequency) or multi-objective criteria.  
   - Fine-tune the GA (population size, mutation rate, etc.) for better or faster convergence.

For inquiries or collaboration, please contact:  
**talebika@ualberta.ca**
