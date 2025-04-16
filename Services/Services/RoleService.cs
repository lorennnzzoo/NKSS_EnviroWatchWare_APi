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

        public void CreateAdminRole()
        {
            var existingRoles = GetAllRoles();
            //if (existingRoles.Any()||existingRoles==null)
            //{
                var adminRole = existingRoles.Where(e => e.Name.ToUpper() == "ADMIN").FirstOrDefault();
                if (adminRole==null)
                {
                    Models.Post.Authentication.Role role = new Models.Post.Authentication.Role
                    {
                        Name = "Admin",
                        Description = "Administrator"
                    };
                    _roleRepository.CreateRole(role);
                }
                var customerRole=existingRoles.Where(e => e.Name.ToUpper() == "CUSTOMER").FirstOrDefault();
                if (customerRole == null)
                {
                    Models.Post.Authentication.Role role = new Models.Post.Authentication.Role
                    {
                        Name = "Customer",
                        Description = "Customer"
                    };
                    _roleRepository.CreateRole(role);
                }
                var serviceRole = existingRoles.Where(e => e.Name.ToUpper() == "SERVICE").FirstOrDefault();
                if (serviceRole == null)
                {
                    Models.Post.Authentication.Role role = new Models.Post.Authentication.Role
                    {
                        Name = "Service",
                        Description = "Customer"
                    };
                    _roleRepository.CreateRole(role);
                }
            //}
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
