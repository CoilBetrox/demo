package com.example.rdtr.demo.dto;

import jakarta.validation.constraints.*;
import java.time.LocalDate;

import lombok.Data;

@Data
public class EstudianteRequestDTO {

    @NotBlank(message = "El nombre es obligatorio")
    private String nombre;

    @NotBlank(message = "El apellido es obligatorio")
    private String apellido;

    @NotBlank(message = "El email es obligatorio")
    @Email(message = "Email no válido")
    private String email;

    @NotNull(message = "La fecha de nacimiento es obligatoria")
    @Past(message = "La fecha de nacimiento debe ser en el pasado")
    private LocalDate fechaNacimiento;

    @NotBlank(message = "La carrera es obligatoria")
    private String carrera;

    @NotNull(message = "El promedio es obligatorio")
    @DecimalMin(value = "0.0", message = "El promedio mínimo es 0.0")
    @DecimalMax(value = "5.0", message = "El promedio máximo es 5.0")
    private Double promedio;
    
    private Boolean activo;

}
