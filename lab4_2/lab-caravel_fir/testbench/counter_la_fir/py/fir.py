import numpy as np

def write_data_file(filename, data):
    with open(filename, 'w') as file:
        for value in data:
            file.write(f"{value:.0f}\n")

def read_input_file(filename):
    with open(filename, 'r') as file:
        return [float(line.strip()) for line in file.readlines()]

def fir_filter(input_data, coefficients, tap_num, output_length=None):
    output_length = output_length or len(input_data)
    output_data = []
    
    for i in range(output_length):
        value = sum(coefficients[j] * (input_data[i - j] if (i - j) >= 0 else 0) for j in range(tap_num))
        output_data.append(int(round(value)))
    return output_data

def main():
    input_data = list(range(64))
    write_data_file("x.dat", input_data)

    coefficients = [0, -10, -9, 23, 56, 63, 56, 23, -9, -10, 0]
    write_data_file("coef.dat", coefficients)

    output_data = fir_filter(input_data, coefficients, tap_num=len(coefficients), output_length=len(input_data))

    write_data_file("y.dat", output_data)

    print("Generated x.dat, coef.dat, and computed y.dat.")

if __name__ == "__main__":
    main()
