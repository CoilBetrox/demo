package com.example.rdtr.demo.service.impl;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.rdtr.demo.dto.EstudianteRequestDTO;
import com.example.rdtr.demo.dto.EstudianteResponseDTO;
import com.example.rdtr.demo.entity.Estudiante;
import com.example.rdtr.demo.exception.ResourceNotFoundException;
import com.example.rdtr.demo.repository.EstudianteRepository;
import com.example.rdtr.demo.service.EstudianteService;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class EstudianteServiceImpl implements EstudianteService{

    private final EstudianteRepository estudianteRepository;

    @Override
    @Transactional
    public EstudianteResponseDTO crearEstudiante(EstudianteRequestDTO requestDTO) {
        if (estudianteRepository.existsByEmail(requestDTO.getEmail())) {
            throw new IllegalArgumentException("El email ya está registrado");
        }
        Estudiante estudiante = new Estudiante();
        mapRequestToEntity(requestDTO, estudiante);
        
        Estudiante saved = estudianteRepository.save(estudiante);
        return mapEntityToResponse(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public EstudianteResponseDTO obtenerEstudiantePorId(Long id) {
        Estudiante estudiante = estudianteRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Estudiante no encontrado con id: " + id));
        return mapEntityToResponse(estudiante);
    }

    @Override
    @Transactional(readOnly = true)
    public List<EstudianteResponseDTO> obtenerTodosLosEstudiantes() {
        return estudianteRepository.findAll().stream()
            .map(this::mapEntityToResponse)
            .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<EstudianteResponseDTO> obtenerEstudiantesActivos() {
        return estudianteRepository.findByActivoTrue().stream()
            .map(this::mapEntityToResponse)
            .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<EstudianteResponseDTO> obtenerEstudiantesPorCarrera(String carrera) {
        return estudianteRepository.findByCarrera(carrera).stream()
                .map(this::mapEntityToResponse)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public EstudianteResponseDTO actualizarEstudiante(Long id, EstudianteRequestDTO requestDTO) {
        Estudiante estudiante = estudianteRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Estudiante no encontrado con id: " + id));
        
        if (!estudiante.getEmail().equals(requestDTO.getEmail()) && 
            estudianteRepository.existsByEmail(requestDTO.getEmail())) {
            throw new IllegalArgumentException("El email ya está registrado");
        }
        
        mapRequestToEntity(requestDTO, estudiante);
        Estudiante updated = estudianteRepository.save(estudiante);
        return mapEntityToResponse(updated);
    }
   
    @Override
    @Transactional
    public void desactivarEstudiante(Long id) {
        Estudiante estudiante = estudianteRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Estudiante no encontrado con id: " + id));
        estudiante.setActivo(false);
        estudianteRepository.save(estudiante);
    }

    @Override
    @Transactional
    public void eliminarEstudiante(Long id) {
        if (!estudianteRepository.existsById(id)) {
            throw new ResourceNotFoundException("Estudiante no encontrado con id: " + id);
        }
        estudianteRepository.deleteById(id);
    }

    private void mapRequestToEntity(EstudianteRequestDTO dto, Estudiante entity) {
        entity.setNombre(dto.getNombre());
        entity.setApellido(dto.getApellido());
        entity.setEmail(dto.getEmail());
        entity.setFechaNacimiento(dto.getFechaNacimiento());
        entity.setCarrera(dto.getCarrera());
        entity.setPromedio(dto.getPromedio());
        entity.setActivo(dto.getActivo());
    }
    
    private EstudianteResponseDTO mapEntityToResponse(Estudiante entity) {
        EstudianteResponseDTO response = new EstudianteResponseDTO();
        response.setId(entity.getId());
        response.setNombre(entity.getNombre());
        response.setApellido(entity.getApellido());
        response.setEmail(entity.getEmail());
        response.setFechaNacimiento(entity.getFechaNacimiento());
        response.setCarrera(entity.getCarrera());
        response.setPromedio(entity.getPromedio());
        response.setActivo(entity.getActivo());
        response.setFechaCreacion(entity.getFechaCreacion());
        return response;
    }

}
