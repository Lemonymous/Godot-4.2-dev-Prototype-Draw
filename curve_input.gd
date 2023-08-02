# Represents an input object for curve mapping operations.
class_name CurveInput
extends RefCounted


# The minimum and maximum values of the input and output ranges for curve mapping.
var imin: float
var imax: float
var omin: float
var omax: float


# Initializes the CurveInput object with the specified input and output ranges.
func _init(_imin: float = 0.0, _imax: float = 1.0, _omin: float = 0.0, _omax: float = 1.0):
	imin = _imin
	imax = _imax
	omin = _omin
	omax = _omax


# Computes the value of a decreasing exponential curve function with the given input and steepness.
static func decreasing_exponential_curve(x: float, steepness: float = 1.0) -> float:
	return exp(-steepness * x)


# Computes the inverse value of a decreasing exponential curve function with the given input and steepness.
static func inverse_decreasing_exponential_curve(x: float, steepness: float = 1.0) -> float:
	if x <= 0.0:
		return INF
	return -log(x) / steepness


# Computes the value of a quadratic curve function with the given input and steepness.
static func quadratic_curve(x: float, steepness: float = 1.0) -> float:
	return pow(x, 2.0 / steepness)


# Computes the inverse value of a quadratic curve function with the given input and steepness.
static func inverse_quadratic_curve(x: float, steepness: float = 1.0) -> float:
	if x < 0.0:
		return 0.0
	else:
		return pow(x, steepness / 2.0)


# Maps the given weight value using the specified curve function and steepness, within the defined input and output ranges.
func map(weight: float, curve_func: Callable, steepness: float = 1.0) -> float:
	var normalized_weight  = (weight - imin) / (imax - imin)
	var curve_value = curve_func.call(normalized_weight, steepness)
	var mapped_value = curve_value * (omax - omin) + omin
	return mapped_value


# Performs inverse mapping of the given mapped value using the specified curve function and steepness, within the defined input and output ranges.
func inverse_map(mapped_value: float, curve_func: Callable, steepness: float = 1.0) -> float:
	var scaled_output = (mapped_value - omin) / (omax - omin)
	var scaled_input = curve_func.call(scaled_output, steepness)
	var inverse_mapped_value = scaled_input * (imax - imin) + imin
	return inverse_mapped_value
