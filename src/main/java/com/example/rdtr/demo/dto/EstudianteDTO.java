package com.example.rdtr.demo.dto;

import java.time.LocalDate;

import lombok.Data;

@Data
public class EstudianteDTO {
    private Long id;
    private String nombre;
    private String apellido;
    private String email;
    private LocalDate fechaNacimiento;
    private String carrera;
    private Double promedio;
    private Boolean activo;
}
