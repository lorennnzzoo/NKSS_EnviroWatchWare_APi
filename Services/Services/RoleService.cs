using Models;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class RoleService : IRoleService
    {
        private IRoleRepository _roleRepository;
        public RoleService(IRoleRepository roleRepository)
        {
            _roleRepository = roleRepository;
        }
        public IEnumerable<Role> GetAllRoles()
        {
            return _roleRepository.GetAll();
        }

        public Role GetRoleById(int id)
        {
            return _roleRepository.GetAll().Where(e => e.Id == id).FirstOrDefault();
        }
    }
}
