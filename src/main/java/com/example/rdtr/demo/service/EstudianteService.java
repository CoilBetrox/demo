package com.example.rdtr.demo.service;

import java.util.List;

import com.example.rdtr.demo.dto.EstudianteRequestDTO;
import com.example.rdtr.demo.dto.EstudianteResponseDTO;

public interface EstudianteService {
    EstudianteResponseDTO crearEstudiante(EstudianteRequestDTO estudianteRequestDTO);
    EstudianteResponseDTO obtenerEstudiantePorId(Long id);
    List<EstudianteResponseDTO> obtenerTodosLosEstudiantes();
    List<EstudianteResponseDTO> obtenerEstudiantesActivos();
    List<EstudianteResponseDTO> obtenerEstudiantesPorCarrera(String carrera);
    EstudianteResponseDTO actualizarEstudiante(Long id, EstudianteRequestDTO estudianteRequestDTO);
    void desactivarEstudiante(Long id);
    void eliminarEstudiante(Long id);
}
