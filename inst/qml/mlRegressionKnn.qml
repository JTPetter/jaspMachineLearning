//
// Copyright (C) 2013-2021 University of Amsterdam
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see
// <http://www.gnu.org/licenses/>.
//

import QtQuick									2.8
import QtQuick.Layouts							1.3
import JASP.Controls							1.0
import JASP.Widgets								1.0

import "./common" as ML

Form 
{

	VariablesForm
	{
		AvailableVariablesList
		{
			name:								"variables"
		}

		AssignedVariablesList
		{
			id:									target
			name:								"target"
			title:								qsTr("Target")
			singleVariable:						true
			allowedColumns:						["scale"]
		}

		AssignedVariablesList
		{
			id:									predictors
			name:								"predictors"
			title:								qsTr("Features")
			allowedColumns:						["scale", "nominal", "nominalText", "ordinal"]
			allowAnalysisOwnComputedColumns:	false
		}
	}

	Group
	{
		title:									qsTr("Tables")

		CheckBox
		{
			text:								qsTr("Evaluation metrics")
			name:								"validationMeasures"
		}

	}

	Group
	{
		title:									qsTr("Plots")

		CheckBox
		{
			text:								qsTr("Data split")
			name:								"dataSplitPlot"
			checked:							true
		}

		CheckBox
		{
			text:								qsTr("Weight function")
			name:								"weightsPlot"
		}

		CheckBox
		{
			text:								qsTr("Mean squared error")
			name:								"errorVsKPlot"
			enabled:							optimizeModel.checked
		}

		CheckBox
		{
			text:								qsTr("Predictive performance")
			name:								"predictedPerformancePlot"
		}
	}

	ML.ExportResults
	{
		enabled:								predictors.count > 0 && target.count > 0
	}

	ML.DataSplit
	{
		trainingValidationSplit:				optimizeModel.checked
	}

	Section
	{
		title:									qsTr("Training Parameters")

		Group
		{
			title:								qsTr("Algorithmic Settings")

			DropDown
			{
				name:							"weights"
				indexDefaultValue:				0
				label:							qsTr("Weights")
				values:
					[
					{ label: qsTr("Rectangular"), 	value: "rectangular"},
					{ label: qsTr("Triangular"), 	value: "triangular"},
					{ label: qsTr("Epanechnikov"), 	value: "epanechnikov"},
					{ label: qsTr("Biweight"), 		value: "biweight"},
					{ label: qsTr("Triweight"), 	value: "triweight"},
					{ label: qsTr("Cosine"), 		value: "cos"},
					{ label: qsTr("Inverse"), 		value: "inv"},
					{ label: qsTr("Gaussian"), 		value: "gaussian"},
					{ label: qsTr("Rank"), 			value: "rank"},
					{ label: qsTr("Optimal"), 		value: "optimal"}
				]
			}

			DropDown
			{
				name:							"distanceParameterManual"
				indexDefaultValue:				0
				label:							qsTr("Distance")
				values:
					[
					{ label:qsTr("Euclidian"),	value:"2"},
					{ label:qsTr("Manhattan"),	value:"1"}
				]
			}

			CheckBox
			{
				text:							qsTr("Scale variables")
				name:							"scaleVariables"
				checked:						true
			}

			CheckBox
			{
				name:							"setSeed"
				text:							qsTr("Set seed")
				childrenOnSameRow:				true

				IntegerField
				{
					name:						"seed"
					defaultValue:				1
					min:						-999999
					max:						999999
					fieldWidth:					60
				}
			}
		}

		RadioButtonGroup
		{
			title:								qsTr("Number of Nearest Neighbors")
			name:								"modelOptimization"

			RadioButton
			{
				text:							qsTr("Fixed")
				name:							"manual"

				IntegerField {
					name:						"noOfNearestNeighbours"
					text:						qsTr("Nearest neighbors")
					defaultValue:				3
					min:						1
					max:						50000
					fieldWidth:					60
				}
			}

			RadioButton
			{
				id:								optimizeModel
				text:							qsTr("Optimized")
				name:							"optimized"
				checked:						true

				IntegerField
				{
					name:						"maxNearestNeighbors"
					text:						qsTr("Max. nearest neighbors")
					defaultValue:				10
					min:						1
					max:						50000
					fieldWidth:					60
				}
			}
		}
	}
}
