using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Linq;
using System.Collections.Generic;
using System;

namespace Services
{
    public class MonitoringTypeService : IMonitoringTypeService
    {
        private readonly IMonitoringTypeRepository _monitoringTypeRepository;
        public MonitoringTypeService(IMonitoringTypeRepository monitoringTypeRepository)
        {
            _monitoringTypeRepository = monitoringTypeRepository;
        }

        public void CreateDefaultMonitoringTypes()
        {
            IEnumerable<MonitoringType> existingMonitoringTypes = GetAllMonitoringTypes();
            var defaultTypes = new List<string> { "STACK", "WATER", "AMBIENT" };
            foreach(string typeName in defaultTypes)
            {
                if (!existingMonitoringTypes.Any(mt => mt.MonitoringTypeName.Equals(typeName, StringComparison.OrdinalIgnoreCase)))
                {
                    Post.MonitoringType monitoringType = new Post.MonitoringType
                    {
                        MonitoringTypeName = typeName
                    };
                    CreateMonitoringType(monitoringType);
                }
            }
        }

        public void CreateMonitoringType(Models.Post.MonitoringType monitoringType)
        {
            _monitoringTypeRepository.Add(monitoringType);
        }

        public void DeleteMonitoringType(int id)
        {
            _monitoringTypeRepository.Delete(id);
        }

        public IEnumerable<Models.MonitoringType> GetAllMonitoringTypes()
        {
            return _monitoringTypeRepository.GetAll();
        }

        public Models.MonitoringType GetMonitoringTypeById(int id)
        {
            return _monitoringTypeRepository.GetById(id);
        }

        public void UpdateMonitoringType(Models.MonitoringType monitoringType)
        {
            _monitoringTypeRepository.Update(monitoringType);
        }
    }
}
